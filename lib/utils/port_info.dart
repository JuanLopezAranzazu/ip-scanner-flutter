/// Descripciones amigables de los puertos más comunes que se detectan en
/// dispositivos de una red doméstica.
const Map<int, String> _portDescriptions = {
  21: 'FTP (transferencia de archivos)',
  22: 'SSH (acceso remoto seguro)',
  23: 'Telnet',
  53: 'DNS',
  80: 'HTTP (servidor web)',
  135: 'RPC de Windows',
  139: 'NetBIOS (redes Windows)',
  443: 'HTTPS (servidor web seguro)',
  445: 'SMB (compartición de archivos Windows)',
  548: 'AFP (compartición de archivos Apple)',
  631: 'IPP (impresora en red)',
  3389: 'Escritorio remoto (RDP)',
  5000: 'Servicio web local',
  5353: 'mDNS / Bonjour',
  8080: 'HTTP alternativo',
  8443: 'HTTPS alternativo',
  62078: 'Sincronización de iPhone/iPad',
};

/// Devuelve una descripción legible de un puerto conocido.
String describePort(int port) =>
    _portDescriptions[port] ?? 'Servicio no identificado';

/// Heurística simple para adivinar qué tipo de dispositivo es, según qué
/// puertos tiene abiertos. No es una detección exacta, solo una
/// aproximación basada en patrones comunes.
String guessDeviceType(List<int> openPorts) {
  final ports = openPorts.toSet();

  if (ports.contains(631)) return 'Probablemente una impresora';
  if (ports.contains(62078)) {
    return 'Probablemente un iPhone o iPad';
  }
  if (ports.contains(548)) return 'Probablemente un Mac';
  if (ports.contains(3389)) {
    return 'Probablemente una PC con Escritorio Remoto activado';
  }
  if (ports.contains(445) || ports.contains(139) || ports.contains(135)) {
    return 'Probablemente una PC con Windows';
  }
  if (ports.contains(22) &&
      !ports.contains(80) &&
      !ports.contains(443) &&
      !ports.contains(8080)) {
    return 'Probablemente un servidor o dispositivo Linux/IoT';
  }
  if (ports.contains(80) || ports.contains(443) || ports.contains(8080)) {
    return 'Probablemente un router, cámara IP o servidor web';
  }
  if (ports.isEmpty) {
    return 'Dispositivo activo (sin puertos abiertos detectados)';
  }
  return 'Tipo de dispositivo desconocido';
}
