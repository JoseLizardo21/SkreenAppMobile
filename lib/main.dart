import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:skreen_app_mobile/helpers/screen_info_helper.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'services/websocket_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Skreen App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Skreen App'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final WebSocketService _wsService = WebSocketService();
  bool _isConnected = false;
  String _status = 'Desconectado';
  final TextEditingController _ipController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _ipController.text = '192.168.1.40';
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    if (!kIsWeb) {
      _enableWakelock();
    }
  }

  /// Method to enable Wakelock after Flutter initialization
  Future<void> _enableWakelock() async {
    try {
      await WakelockPlus.enable();
    } catch (e) {
      print('Error enabling Wakelock: $e');
    }
  }

  Future<void> _connectAndRegister() async {
    try {
      // Conectar al servidor WebSocket
      await _wsService.connect('ws://${_ipController.text.trim()}:9001');
      // Registrarse como cliente Flutter
      await _wsService.registerAsFlutter();

      setState(() {
        _isConnected = true;
        _status = 'Conectado';
      });

      // Escuchar mensajes del servidor
      _wsService.messageStream.listen(
        (message) {
          print('Mensaje recibido: $message');
        },
        onError: (error) {
          print('Error en WebSocket: $error');
          setState(() {
            _isConnected = false;
            _status = 'Error de conexión';
          });
        },
        onDone: () {
          print('Conexión cerrada');
          setState(() {
            _isConnected = false;
            _status = 'Desconectado';
          });
        },
      );
    } catch (e) {
      print('Error: $e');
      setState(() {
        _status = 'Error: $e';
      });
    }
  }

  Future<void> _disconnect() async {
    await _wsService.disconnect();
    setState(() {
      _isConnected = false;
      _status = 'Desconectado';
    });
  }

  @override
  void dispose() {
    _wsService.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Estado: $_status',
              style: TextStyle(
                color: _isConnected ? Colors.green : Colors.red,
                fontSize: 20,
              ),
            ),
            SizedBox(height: 30),
            if (!_isConnected)
              Container(
                width: 500,
                margin: EdgeInsets.only(bottom: 20),
                child: TextField(
                  controller: _ipController,
                  decoration: InputDecoration(
                    labelText: 'Dirección IP del servidor',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ElevatedButton(
              onPressed: _isConnected ? _disconnect : _connectAndRegister,
              child: Text(_isConnected ? 'Desconectar' : 'Conectar'),
            ),
            if (_isConnected) ...[
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  // Get real screen resolution
                  final screenResolution =
                      await ScreenInfoHelper.getRealScreenResolution();
                  final int screenWidth = screenResolution['width']!;
                  final int screenHeight = screenResolution['height']!;
                  final jsonString = jsonEncode({
                    'type': 'screen_info',
                    'width': screenWidth,
                    'height': screenHeight,
                  });
                  _wsService.sendMessage(jsonString);
                },
                child: Text('Enviar mensaje'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
