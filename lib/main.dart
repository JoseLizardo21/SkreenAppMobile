import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'services/websocket_service.dart';
import 'services/webrtc_manager.dart';

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
  final WebRTCManager _webrtcManager = WebRTCManager();

  bool _isConnected = false;
  bool _isVideoPlaying = false;
  String _status = 'Desconectado';
  String _connectionState = '';
  final TextEditingController _ipController = TextEditingController();

  @override
  void initState() {
    super.initState();

    _ipController.text = '192.168.100.89';
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    if (!kIsWeb) {
      _enableWakelock();
    }

    // ⬇️ MUY IMPORTANTE
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeWebRTC();
    });
  }

  Future<void> _enableWakelock() async {
    try {
      await WakelockPlus.enable();
    } catch (e) {
      print('Error enabling Wakelock: $e');
    }
  }

  Future<void> _initializeWebRTC() async {
    // Configurar callbacks del WebRTC Manager
    _webrtcManager.onVideoStarted = () {
      setState(() {
        _isVideoPlaying = true;
        _status = 'Video recibido ✅';
      });
    };

    _webrtcManager.onError = (error) {
      setState(() {
        _status = 'Error: $error';
      });
    };

    _webrtcManager.onConnectionStateChanged = (state) {
      setState(() {
        _connectionState = state.toString().split('.').last;
      });
    };

    // Inicializar WebRTC
    await _webrtcManager.initialize();
  }

  Future<void> _connectAndRegister() async {
    try {
      setState(() {
        _status = 'Conectando...';
      });

      // Conectar al servidor WebSocket
      await _wsService.connect('ws://${_ipController.text.trim()}:9001');

      // Registrarse como cliente Flutter
      await _wsService.registerAsFlutter();

      setState(() {
        _isConnected = true;
        _status = 'Conectado - Enviando resolución...';
      });

      // Enviar información del dispositivo automáticamente (incluyendo resolución)
      await _sendDeviceInfo();
    } catch (e) {
      print('Error: $e');
      setState(() {
        _status = 'Error: $e';
        _isConnected = false;
      });
    }
  }

  Future<void> _sendDeviceInfo() async {
    try {
      // Obtener resolución real de la pantalla
      // final screenResolution = await ScreenInfoHelper.getRealScreenResolution();
      // final int screenWidth = screenResolution['width']!;
      // final int screenHeight = screenResolution['height']!;

      final jsonString = jsonEncode({
        'type': 'screen_info',
        'device_name': 'Flutter Device',
        'width': 1200,
        'height': 800,
      });

      _wsService.sendMessage(jsonString);

      // print('📤 Device info enviado: ${screenWidth}x${screenHeight}');

      setState(() {
        _status = 'Info enviada - Esperando stream...';
      });
    } catch (e) {
      print('Error enviando device info: $e');
    }
  }

  Future<void> _disconnect() async {
    await _wsService.disconnect();
    setState(() {
      _isConnected = false;
      _isVideoPlaying = false;
      _status = 'Desconectado';
      _connectionState = '';
    });
  }

  @override
  void dispose() {
    _wsService.disconnect();
    _webrtcManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ========== Video Stream ==========
          if (_isVideoPlaying)
            Center(
              child: RTCVideoView(
                _webrtcManager.remoteRenderer,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
                mirror: false,
              ),
            )
          else
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isConnected)
                    CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 20),
                  Text(
                    _status,
                    style: TextStyle(color: Colors.white, fontSize: 18),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

          // ========== Panel de control (superior) ==========
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 10,
                left: 20,
                right: 20,
                bottom: 10,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withOpacity(0.7), Colors.transparent],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Indicador de estado
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: _isConnected
                              ? (_isVideoPlaying ? Colors.green : Colors.orange)
                              : Colors.red,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: _isConnected
                                  ? (_isVideoPlaying
                                        ? Colors.green
                                        : Colors.orange)
                                  : Colors.red,
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _status,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_connectionState.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 5, left: 22),
                      child: Text(
                        'Estado: $_connectionState',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ========== Controles (inferior) ==========
          if (!_isVideoPlaying)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black.withOpacity(0.8), Colors.transparent],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!_isConnected)
                      Container(
                        margin: EdgeInsets.only(bottom: 20),
                        child: TextField(
                          controller: _ipController,
                          style: TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'IP del servidor',
                            labelStyle: TextStyle(color: Colors.white70),
                            border: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.white),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.white54),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ElevatedButton(
                      onPressed: _isConnected
                          ? _disconnect
                          : _connectAndRegister,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isConnected
                            ? Colors.red
                            : Colors.deepPurple,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 15,
                        ),
                        minimumSize: Size(double.infinity, 50),
                      ),
                      child: Text(
                        _isConnected ? 'Desconectar' : 'Conectar',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            // Botón flotante de desconexión cuando hay video
            Positioned(
              bottom: 20,
              right: 20,
              child: FloatingActionButton(
                onPressed: _disconnect,
                backgroundColor: Colors.red,
                child: Icon(Icons.close),
              ),
            ),
        ],
      ),
    );
  }
}
