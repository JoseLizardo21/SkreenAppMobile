import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import '../models/connection_mode.dart';

class ConnectionModeScreen extends StatefulWidget {
  const ConnectionModeScreen({super.key});

  @override
  State<ConnectionModeScreen> createState() => _ConnectionModeScreenState();
}

class _ConnectionModeScreenState extends State<ConnectionModeScreen> {
  static final RegExp _ipRegex =
      RegExp(r'^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$');

  ConnectionMode _mode = ConnectionMode.cable;
  final TextEditingController _ipController = TextEditingController();
  String? _ipError;

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }

  bool _isValidIp(String value) {
    final match = _ipRegex.firstMatch(value.trim());
    if (match == null) return false;
    for (int i = 1; i <= 4; i++) {
      final part = int.tryParse(match.group(i)!);
      if (part == null || part > 255) return false;
    }
    return true;
  }

  void _continue() {
    if (_mode == ConnectionMode.cable) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SkreenPage(config: ConnectionConfig.cable()),
        ),
      );
      return;
    }

    final ip = _ipController.text.trim();
    if (!_isValidIp(ip)) {
      setState(() => _ipError = 'Ingresa una IP válida (ej. 192.168.1.34)');
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SkreenPage(config: ConnectionConfig.wifi(ip)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWifi = _mode == ConnectionMode.wifi;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cast_connected, size: 72, color: Colors.deepPurple),
                const SizedBox(height: 16),
                const Text(
                  'Skreen App',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  '¿Cómo quieres conectarte?',
                  style: TextStyle(fontSize: 16, color: Colors.black54),
                ),
                const SizedBox(height: 24),
                SegmentedButton<ConnectionMode>(
                  segments: const [
                    ButtonSegment(
                      value: ConnectionMode.cable,
                      label: Text('Cable'),
                      icon: Icon(Icons.usb),
                    ),
                    ButtonSegment(
                      value: ConnectionMode.wifi,
                      label: Text('WiFi'),
                      icon: Icon(Icons.wifi),
                    ),
                  ],
                  selected: {_mode},
                  onSelectionChanged: (selection) {
                    setState(() {
                      _mode = selection.first;
                      _ipError = null;
                    });
                  },
                ),
                if (isWifi) ...[
                  const SizedBox(height: 24),
                  const Text(
                    'Ingresa la IP que muestra la app de escritorio en tu misma red WiFi',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _ipController,
                    keyboardType: const TextInputType.numberWithOptions(),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    decoration: InputDecoration(
                      labelText: 'IP de la PC',
                      hintText: '192.168.1.34',
                      border: const OutlineInputBorder(),
                      errorText: _ipError,
                    ),
                    onChanged: (_) {
                      if (_ipError != null) setState(() => _ipError = null);
                    },
                  ),
                ],
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _continue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: const Text('Continuar', style: TextStyle(fontSize: 16)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
