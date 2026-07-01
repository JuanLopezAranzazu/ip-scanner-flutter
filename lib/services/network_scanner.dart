import 'dart:async';
import 'dart:io';

import 'package:network_info_plus/network_info_plus.dart';

import '../models/device_info.dart';

/// Escanea la red local (LAN) buscando dispositivos activos.
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
    5000,
    631,
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
  Stream<DeviceInfo> scanNetwork({
    Duration timeout = const Duration(milliseconds: 400),
    int concurrency = 32,
  }) async* {
    final prefix = await getSubnetPrefix();
    if (prefix == null) {
      throw Exception(
        'No se pudo detectar la red WiFi. Verifica que el WiFi esté activado y conectado.',
      );
    }

    final controller = StreamController<DeviceInfo>();
    final ips = List.generate(254, (i) => '$prefix.${i + 1}');

    // Procesamos en lotes para no abrir 254 sockets todos a la vez.
    unawaited(_runInBatches(ips, concurrency, timeout, controller));

    yield* controller.stream;
  }

  Future<void> _runInBatches(
    List<String> ips,
    int concurrency,
    Duration timeout,
    StreamController<DeviceInfo> controller,
  ) async {
    for (var i = 0; i < ips.length; i += concurrency) {
      final batch = ips.skip(i).take(concurrency);
      await Future.wait(batch.map((ip) async {
        final alive = await _isHostAlive(ip, timeout);
        if (alive) {
          final hostname = await _resolveHostname(ip);
          if (!controller.isClosed) {
            controller.add(DeviceInfo(ip: ip, hostname: hostname));
          }
        }
      }));
    }
    await controller.close();
  }

  Future<bool> _isHostAlive(String ip, Duration timeout) async {
    for (final port in _commonPorts) {
      try {
        final socket = await Socket.connect(ip, port, timeout: timeout);
        socket.destroy();
        return true; // Puerto abierto -> dispositivo activo
      } on SocketException catch (e) {
        final refused = e.osError?.errorCode == 111 ||
            e.message.toLowerCase().contains('refused');
        if (refused) {
          return true; // Host respondió aunque el puerto esté cerrado
        }
        // Timeout / host inalcanzable en este puerto -> probamos el siguiente
      } catch (_) {
        // Ignoramos y seguimos con el siguiente puerto
      }
    }
    return false;
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
