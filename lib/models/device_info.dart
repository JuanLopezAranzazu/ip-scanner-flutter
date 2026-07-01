/// Representa un dispositivo encontrado en la red local, con la
/// información recolectada durante el escaneo.
class DeviceInfo {
  final String ip;
  final String? hostname;

  /// Puertos que respondieron como abiertos durante el escaneo.
  final List<int> openPorts;

  /// Tiempo de respuesta más rápido obtenido de cualquiera de los puertos
  /// probados, en milisegundos. Null si no se pudo medir.
  final int? latencyMs;

  /// Momento en que se detectó el dispositivo.
  final DateTime scannedAt;

  DeviceInfo({
    required this.ip,
    this.hostname,
    this.openPorts = const [],
    this.latencyMs,
    DateTime? scannedAt,
  }) : scannedAt = scannedAt ?? DateTime.now();
}
