import 'package:flutter/material.dart';

import '../models/device_info.dart';
import '../utils/port_info.dart';

/// Fila que representa un dispositivo dentro de la lista de resultados.
class DeviceTile extends StatelessWidget {
  final DeviceInfo device;
  final bool isThisDevice;
  final VoidCallback? onTap;

  const DeviceTile({
    super.key,
    required this.device,
    this.isThisDevice = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = device.hostname != null
        ? '${device.ip} · ${guessDeviceType(device.openPorts)}'
        : guessDeviceType(device.openPorts);

    return ListTile(
      onTap: onTap,
      leading: Icon(
        isThisDevice ? Icons.smartphone : Icons.devices,
        color: isThisDevice ? Theme.of(context).colorScheme.primary : null,
      ),
      title: Text(device.hostname ?? device.ip),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: isThisDevice
          ? const Chip(label: Text('Este dispositivo'))
          : const Icon(Icons.chevron_right),
    );
  }
}
