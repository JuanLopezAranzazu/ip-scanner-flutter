import 'dart:async';
import 'dart:io';

import 'package:network_info_plus/network_info_plus.dart';

import '../models/device_info.dart';

/// Resultado interno de probar un puerto específico de una IP.
class _PortProbe {
  final int port;
  final bool open;
  final bool refused;
  final int? latencyMs;

  _PortProbe({
    required this.port,
    required this.open,
    required this.refused,
    this.latencyMs,
  });
}

/// Escanea la red local (LAN) buscando dispositivos activos y recolectando
/// información adicional de cada uno (puertos abiertos, latencia).
///
/// Flutter no tiene acceso a ICMP "ping" crudo sin permisos nativos
/// especiales, así que usamos una técnica alternativa muy común:
/// intentamos abrir una conexión TCP a varios puertos típicos de cada IP.
///
/// - Si la conexión se establece -> el puerto está abierto -> dispositivo activo.
/// - Si la conexión es "rechazada" (connection refused) -> el host SÍ existe
///   y respondió, solo que ese puerto está cerrado -> dispositivo activo.
/// - Si hay timeout (no responde nada) -> probablemente no hay ningún
///   dispositivo en esa IP, o tiene un firewall que descarta paquetes.
///
/// Todos los puertos de una misma IP se prueban en paralelo (no uno por
/// uno), para que el costo de revisar una IP "muerta" sea como máximo el
/// timeout configurado, en vez de la suma de todos los timeouts.
class NetworkScanner {
  final NetworkInfo _networkInfo = NetworkInfo();

  /// Puertos comunes a probar. Cubren routers, impresoras, compartición de
  /// archivos, servicios web locales, iPhones (62078), etc.
  static const List<int> _commonPorts = [
    80,
    443,
    22,
    8080,
    445,
    139,
    135,
    62078,
    8443,
    631,
    3389,
    21,
    23,
  ];

  /// Devuelve el prefijo de subred (ej. "192.168.1") a partir de la IP WiFi
  /// del dispositivo. Retorna null si no hay conexión WiFi.
  Future<String?> getSubnetPrefix() async {
    final wifiIP = await _networkInfo.getWifiIP();
    if (wifiIP == null) return null;
    final parts = wifiIP.split('.');
    if (parts.length != 4) return null;
    return '${parts[0]}.${parts[1]}.${parts[2]}';
  }

  /// Devuelve la IP local completa del dispositivo actual (útil para
  /// marcarla como "Este dispositivo" en la lista).
  Future<String?> getLocalIP() => _networkInfo.getWifiIP();

  /// Escanea todo el rango .1 a .254 de la subred actual.
  ///
  /// Emite un [DeviceInfo] por cada dispositivo encontrado, a medida que
  /// se van detectando (no espera a terminar todo el escaneo).
  ///
  /// [onProgress] se llama después de revisar cada IP (encuentre o no un
  /// dispositivo), útil para alimentar una barra de progreso real.
  Stream<DeviceInfo> scanNetwork({
    Duration timeout = const Duration(milliseconds: 500),
    int concurrency = 40,
    void Function(int completed, int total)? onProgress,
  }) async* {
    final prefix = await getSubnetPrefix();
    if (prefix == null) {
      throw Exception(
        'No se pudo detectar la red WiFi. Verifica que el WiFi esté activado y conectado.',
      );
    }

    final controller = StreamController<DeviceInfo>();
    final ips = List.generate(254, (i) => '$prefix.${i + 1}');

    unawaited(
        _runWithWorkerPool(ips, concurrency, timeout, controller, onProgress));

    yield* controller.stream;
  }

  /// Escanea usando un "pool" de N workers que toman la siguiente IP tan
  /// pronto terminan la anterior, en vez de esperar a que todo un lote
  /// termine (como haría `Future.wait` por bloques). Esto mantiene la
  /// concurrencia siempre al máximo y hace que el progreso avance de forma
  /// continua en vez de "a saltos" cuando una IP lenta atasca un lote
  /// completo.
  Future<void> _runWithWorkerPool(
    List<String> ips,
    int concurrency,
    Duration timeout,
    StreamController<DeviceInfo> controller,
    void Function(int completed, int total)? onProgress,
  ) async {
    final total = ips.length;
    var nextIndex = 0;
    var completed = 0;

    Future<void> worker() async {
      while (true) {
        if (nextIndex >= ips.length) return;
        final ip = ips[nextIndex++];
        await _scanSingleHost(ip, timeout, controller);
        completed++;
        onProgress?.call(completed, total);
        await Future.delayed(const Duration(milliseconds: 1));
      }
    }

    final workerCount = concurrency.clamp(1, ips.length);
    await Future.wait(List.generate(workerCount, (_) => worker()));
    await controller.close();
  }

  Future<void> _scanSingleHost(
    String ip,
    Duration timeout,
    StreamController<DeviceInfo> controller,
  ) async {
    // Probamos TODOS los puertos comunes en paralelo para esta IP.
    final probes = await Future.wait(
      _commonPorts.map((port) => _tryConnect(ip, port, timeout)),
    );

    final openPorts = probes.where((p) => p.open).map((p) => p.port).toList()
      ..sort();
    final wasRefusedSomewhere = probes.any((p) => p.refused);
    final isAlive = openPorts.isNotEmpty || wasRefusedSomewhere;

    if (!isAlive) return;

    final latencies = probes
        .where((p) => p.latencyMs != null)
        .map((p) => p.latencyMs!)
        .toList();
    final bestLatency =
        latencies.isEmpty ? null : latencies.reduce((a, b) => a < b ? a : b);

    final hostname = await _resolveHostname(ip);

    if (!controller.isClosed) {
      controller.add(DeviceInfo(
        ip: ip,
        hostname: hostname,
        openPorts: openPorts,
        latencyMs: bestLatency,
      ));
    }
  }

  Future<_PortProbe> _tryConnect(String ip, int port, Duration timeout) async {
    final stopwatch = Stopwatch()..start();
    try {
      final socket = await Socket.connect(ip, port, timeout: timeout);
      stopwatch.stop();
      socket.destroy();
      return _PortProbe(
        port: port,
        open: true,
        refused: false,
        latencyMs: stopwatch.elapsedMilliseconds,
      );
    } on SocketException catch (e) {
      stopwatch.stop();
      final refused = e.osError?.errorCode == 111 ||
          e.message.toLowerCase().contains('refused');
      return _PortProbe(
        port: port,
        open: false,
        refused: refused,
        latencyMs: refused ? stopwatch.elapsedMilliseconds : null,
      );
    } catch (_) {
      stopwatch.stop();
      return _PortProbe(port: port, open: false, refused: false);
    }
  }

  Future<String?> _resolveHostname(String ip) async {
    try {
      final result = await InternetAddress(ip)
          .reverse()
          .timeout(const Duration(milliseconds: 600));
      return result.host != ip ? result.host : null;
    } catch (_) {
      return null;
    }
  }
}
