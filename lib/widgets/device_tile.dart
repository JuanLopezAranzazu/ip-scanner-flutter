import 'package:flutter/material.dart';

import '../models/device_info.dart';

/// Fila que representa un dispositivo dentro de la lista de resultados.
class DeviceTile extends StatelessWidget {
  final DeviceInfo device;
  final bool isThisDevice;

  const DeviceTile({
    super.key,
    required this.device,
    this.isThisDevice = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        isThisDevice ? Icons.smartphone : Icons.devices,
        color: isThisDevice ? Theme.of(context).colorScheme.primary : null,
      ),
      title: Text(device.hostname ?? device.ip),
      subtitle: device.hostname != null ? Text(device.ip) : null,
      trailing:
          isThisDevice ? const Chip(label: Text('Este dispositivo')) : null,
    );
  }
}
