import 'package:flutter/material.dart';

import '../models/device_info.dart';
import '../services/network_scanner.dart';
import '../widgets/device_tile.dart';

class ScannerHomeScreen extends StatefulWidget {
  const ScannerHomeScreen({super.key});

  @override
  State<ScannerHomeScreen> createState() => _ScannerHomeScreenState();
}

class _ScannerHomeScreenState extends State<ScannerHomeScreen> {
  final NetworkScanner _scanner = NetworkScanner();
  final List<DeviceInfo> _devices = [];

  bool _scanning = false;
  String? _subnet;
  String? _localIP;
  String? _error;

  Future<void> _startScan() async {
    setState(() {
      _devices.clear();
      _scanning = true;
      _error = null;
    });

    try {
      _subnet = await _scanner.getSubnetPrefix();
      _localIP = await _scanner.getLocalIP();

      await for (final device in _scanner.scanNetwork()) {
        setState(() => _devices.add(device));
      }

      // Ordenamos por IP al terminar, para que la lista quede prolija.
      setState(() {
        _devices.sort((a, b) {
          final aLast = int.tryParse(a.ip.split('.').last) ?? 0;
          final bLast = int.tryParse(b.ip.split('.').last) ?? 0;
          return aLast.compareTo(bLast);
        });
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _scanning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Escáner de red')),
      body: Column(
        children: [
          if (_subnet != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  const Icon(Icons.wifi, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'Red: $_subnet.0/24',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const Spacer(),
                  Text(
                    '${_devices.length} encontrados',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          if (_scanning) const LinearProgressIndicator(),
          Expanded(
            child: _devices.isEmpty && !_scanning
                ? Center(
                    child: Text(
                      'Presiona el botón para escanear tu red',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _devices.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final device = _devices[index];
                      return DeviceTile(
                        device: device,
                        isThisDevice: device.ip == _localIP,
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _scanning ? null : _startScan,
        icon: Icon(_scanning ? Icons.hourglass_top : Icons.search),
        label: Text(_scanning ? 'Escaneando...' : 'Escanear red'),
      ),
    );
  }
}
