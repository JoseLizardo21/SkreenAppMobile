import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../helpers/screen_info_helper.dart';
import '../main.dart';
import '../models/connection_mode.dart';
import '../theme/app_colors.dart';

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
  String? _resolution;

  @override
  void initState() {
    super.initState();
    _loadResolution();
  }

  Future<void> _loadResolution() async {
    final res = await ScreenInfoHelper.getRealScreenResolution();
    if (!mounted) return;
    setState(() => _resolution = '${res['width']} × ${res['height']}');
  }

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
      setState(() => _ipError = 'Enter a valid IP (e.g. 192.168.1.34)');
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
        child: Stack(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: Column(
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.cast_connected, size: 72, color: AppColors.primary),
                        const SizedBox(height: 16),
                        const Text(
                          'SkreenApp',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'How do you want to connect?',
                          style: TextStyle(fontSize: 16, color: Colors.white70),
                        ),
                        const SizedBox(height: 24),
                        SegmentedButton<ConnectionMode>(
                          style: SegmentedButton.styleFrom(
                            backgroundColor: Colors.white10,
                            foregroundColor: Colors.white70,
                            selectedBackgroundColor: AppColors.primary,
                            selectedForegroundColor: AppColors.onPrimary,
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
                            'Enter the IP shown by the desktop app on the same WiFi network',
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
                            cursorColor: AppColors.primary,
                            decoration: InputDecoration(
                              labelText: 'PC IP address',
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
                                borderSide: const BorderSide(color: AppColors.primary),
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
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.onPrimary,
                            minimumSize: const Size(double.infinity, 50),
                          ),
                          child: const Text('Continue', style: TextStyle(fontSize: 16)),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            // Device screen resolution
            if (_resolution != null)
              Positioned(
                top: 12,
                right: 16,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.aspect_ratio, size: 16, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text(
                      _resolution!,
                      style: const TextStyle(fontSize: 13, color: Colors.white70),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
