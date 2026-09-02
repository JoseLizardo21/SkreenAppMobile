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
      backgroundColor: Colors.black,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.cast_connected, size: 72, color: Colors.deepPurpleAccent),
                    const SizedBox(height: 16),
                    const Text(
                      'Skreen App',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '¿Cómo quieres conectarte?',
                      style: TextStyle(fontSize: 16, color: Colors.white70),
                    ),
                    const SizedBox(height: 24),
                    SegmentedButton<ConnectionMode>(
                      style: SegmentedButton.styleFrom(
                        backgroundColor: Colors.white10,
                        foregroundColor: Colors.white70,
                        selectedBackgroundColor: Colors.deepPurple,
                        selectedForegroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white24),
                      ),
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
                        style: TextStyle(fontSize: 13, color: Colors.white70),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _ipController,
                        keyboardType: const TextInputType.numberWithOptions(),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                        ],
                        style: const TextStyle(color: Colors.white),
                        cursorColor: Colors.deepPurpleAccent,
                        decoration: InputDecoration(
                          labelText: 'IP de la PC',
                          labelStyle: const TextStyle(color: Colors.white70),
                          hintText: '192.168.1.34',
                          hintStyle: const TextStyle(color: Colors.white38),
                          filled: true,
                          fillColor: Colors.white10,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Colors.white24),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Colors.white24),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Colors.deepPurpleAccent),
                          ),
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
            );
          },
        ),
      ),
    );
  }
}
