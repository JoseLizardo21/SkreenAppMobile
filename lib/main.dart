import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'services/control_connection.dart';
import 'services/webrtc_connection.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Skreen App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple)),
      home: const SkreenPage(),
    );
  }
}

class SkreenPage extends StatefulWidget {
  const SkreenPage({super.key});

  @override
  State<SkreenPage> createState() => _SkreenPageState();
}

class _SkreenPageState extends State<SkreenPage> {
  bool _isConnected = false;
  String _status = 'Disconnected';
  final ControlConnection _controlConn = ControlConnection();
  final WebrtcConnection _webrtc = WebrtcConnection();
  double _videoWidth = 1920;
  double _videoHeight = 1080;

  // Multi-touch tracking
  final Map<int, Offset> _activePointers = {};
  bool _scrollMode = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    WakelockPlus.enable();
    _webrtc.renderer.onResize = () {
      final w = _webrtc.renderer.videoWidth.toDouble();
      final h = _webrtc.renderer.videoHeight.toDouble();
      if (w > 0 && h > 0) setState(() { _videoWidth = w; _videoHeight = h; });
    };
    _webrtc.onConnectionState = (state) {
      if (_isConnected &&
          (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
              state == RTCPeerConnectionState.RTCPeerConnectionStateClosed)) {
        _disconnect();
      }
    };
  }

  Future<void> _connect() async {
    setState(() {
      _isConnected = true;
      _status = 'Connecting...';
    });

    try {
      await _webrtc.connect();
      _controlConn.onStreamStopped = _disconnect;
      await _controlConn.connect().catchError((_) {});
      setState(() {
        _status = 'Streaming';
      });
    } catch (e) {
      debugPrint('[SkreenApp] Error starting WebRTC: $e');
      setState(() {
        _isConnected = false;
        _status = 'Error: $e';
      });
    }
  }

  Future<void> _disconnect() async {
    _controlConn.disconnect();
    await _webrtc.disconnect();
    setState(() {
      _isConnected = false;
      _status = 'Disconnected';
    });
  }

  @override
  void dispose() {
    _controlConn.disconnect();
    _webrtc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Video via WebRTC
          Positioned.fill(
            child: _isConnected
              ? LayoutBuilder(
                  builder: (context, constraints) {
                    // Área real del video respetando el aspect ratio del escritorio
                    final videoAspect = _videoWidth / _videoHeight;
                    final screenAspect = constraints.maxWidth / constraints.maxHeight;
                    final double videoW, videoH;
                    if (screenAspect > videoAspect) {
                      // Pantalla más ancha: pillarbox (barras laterales)
                      videoH = constraints.maxHeight;
                      videoW = videoH * videoAspect;
                    } else {
                      // Pantalla más alta: letterbox (barras arriba/abajo)
                      videoW = constraints.maxWidth;
                      videoH = videoW / videoAspect;
                    }
                    return Listener(
                      onPointerDown: (e) {
                        _activePointers[e.pointer] = e.localPosition;
                        if (_activePointers.length == 1) {
                          _scrollMode = false;
                          final nx = (e.localPosition.dx - (constraints.maxWidth - videoW) / 2) / videoW;
                          final ny = (e.localPosition.dy - (constraints.maxHeight - videoH) / 2) / videoH;
                          if (nx >= 0 && nx <= 1 && ny >= 0 && ny <= 1) {
                            _controlConn.sendEvent(1, 0, nx, ny); // touch down
                          }
                        } else if (_activePointers.length == 2 && !_scrollMode) {
                          _scrollMode = true;
                          _controlConn.sendEvent(2, 0, 0, 0); // cancel pending tap/drag
                        }
                      },
                      onPointerMove: (e) {
                        final prev = _activePointers[e.pointer];
                        _activePointers[e.pointer] = e.localPosition;
                        if (!_scrollMode && _activePointers.length == 1) {
                          final nx = (e.localPosition.dx - (constraints.maxWidth - videoW) / 2) / videoW;
                          final ny = (e.localPosition.dy - (constraints.maxHeight - videoH) / 2) / videoH;
                          _controlConn.sendEvent(0, 0, nx.clamp(0.0, 1.0), ny.clamp(0.0, 1.0)); // move
                        } else if (_scrollMode && _activePointers.length >= 2 && prev != null) {
                          final dy = (e.localPosition.dy - prev.dy) / videoH;
                          if (dy.abs() > 0.001) {
                            _controlConn.sendEvent(3, 0, 0, dy); // scroll
                          }
                        }
                      },
                      onPointerUp: (e) {
                        _activePointers.remove(e.pointer);
                        if (_activePointers.isEmpty) {
                          if (!_scrollMode) {
                            _controlConn.sendEvent(2, 0, 0, 0); // touch up
                          }
                          _scrollMode = false;
                        }
                      },
                      child: Center(
                        child: SizedBox(
                          width: videoW,
                          height: videoH,
                          child: RTCVideoView(_webrtc.renderer),
                        ),
                      ),
                    );
                  },
                )
              : const SizedBox.shrink(),
          ),

          // Texto de estado cuando no está conectado
          if (!_isConnected)
            Center(
              child: Text(
                _status,
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),

          // Botón conectar
          if (!_isConnected)
            Positioned(
              bottom: 40, left: 20, right: 20,
              child: ElevatedButton(
                onPressed: _connect,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Text('Connect', style: TextStyle(fontSize: 16)),
              ),
            )
          else
            Positioned(
              bottom: 20, right: 20,
              child: FloatingActionButton(
                onPressed: _disconnect,
                backgroundColor: Colors.red,
                child: const Icon(Icons.close),
              ),
            ),
        ],
      ),
    );
  }
}
