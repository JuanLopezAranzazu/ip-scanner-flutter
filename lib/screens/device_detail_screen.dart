import 'package:flutter/material.dart';

import '../models/device_info.dart';
import '../utils/port_info.dart';

class DeviceDetailScreen extends StatelessWidget {
  final DeviceInfo device;
  final bool isThisDevice;

  const DeviceDetailScreen({
    super.key,
    required this.device,
    this.isThisDevice = false,
  });

  String _formatTime(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    final s = time.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final deviceType = guessDeviceType(device.openPorts);

    return Scaffold(
      appBar: AppBar(title: const Text('Detalle del dispositivo')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Column(
              children: [
                Icon(
                  isThisDevice ? Icons.smartphone : Icons.devices,
                  size: 64,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 8),
                Text(
                  device.hostname ?? device.ip,
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                if (isThisDevice)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Chip(label: Text('Este dispositivo')),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _SectionCard(
            title: 'Información general',
            children: [
              _InfoRow(
                icon: Icons.language,
                label: 'Dirección IP',
                value: device.ip,
              ),
              if (device.hostname != null)
                _InfoRow(
                  icon: Icons.badge_outlined,
                  label: 'Hostname',
                  value: device.hostname!,
                ),
              _InfoRow(
                icon: Icons.category_outlined,
                label: 'Tipo probable',
                value: deviceType,
              ),
              if (device.latencyMs != null)
                _InfoRow(
                  icon: Icons.speed,
                  label: 'Tiempo de respuesta',
                  value: '${device.latencyMs} ms',
                ),
              _InfoRow(
                icon: Icons.access_time,
                label: 'Detectado a las',
                value: _formatTime(device.scannedAt),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Puertos abiertos (${device.openPorts.length})',
            children: device.openPorts.isEmpty
                ? [
                    const Text(
                      'El dispositivo respondió a la red, pero no se '
                      'detectaron puertos abiertos entre los revisados.',
                    ),
                  ]
                : device.openPorts
                    .map(
                      (port) => _InfoRow(
                        icon: Icons.lan_outlined,
                        label: 'Puerto $port',
                        value: describePort(port),
                      ),
                    )
                    .toList(),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'El tipo de dispositivo es una estimación basada en los '
              'puertos abiertos, no una identificación exacta.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelMedium),
                Text(value, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
