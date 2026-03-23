import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'services/control_connection.dart';

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
  static const _decoderChannel = MethodChannel('skreen/decoder');

  int? _textureId;
  bool _isConnected = false;
  String _status = 'Desconectado';
  final ControlConnection _controlConn = ControlConnection();

  // Multi-touch tracking
  final Map<int, Offset> _activePointers = {};
  bool _scrollMode = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    WakelockPlus.enable();
  }

  Future<void> _connect() async {
    setState(() {
      _isConnected = true;
      _status = 'Conectando...';
    });

    try {
      final textureId = await _decoderChannel.invokeMethod<int>('start');
      await _controlConn.connect().catchError((_) {});
      setState(() {
        _textureId = textureId;
        _status = 'Transmitiendo';
      });
    } catch (e) {
      debugPrint('[SkreenApp] Error al iniciar decoder: $e');
      setState(() {
        _isConnected = false;
        _status = 'Error: $e';
      });
    }
  }

  Future<void> _disconnect() async {
    _controlConn.disconnect();
    await _decoderChannel.invokeMethod('stop');
    setState(() {
      _textureId = null;
      _isConnected = false;
      _status = 'Desconectado';
    });
  }

  @override
  void dispose() {
    _controlConn.disconnect();
    _decoderChannel.invokeMethod('stop');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Video via MediaCodec nativo
          Positioned.fill(
            child: _textureId != null
              ? LayoutBuilder(
                  builder: (context, constraints) => Listener(
                    onPointerDown: (e) {
                      _activePointers[e.pointer] = e.localPosition;
                      if (_activePointers.length == 1) {
                        _scrollMode = false;
                        final nx = e.localPosition.dx / constraints.maxWidth;
                        final ny = e.localPosition.dy / constraints.maxHeight;
                        _controlConn.sendEvent(1, 0, nx, ny); // touch down
                      } else if (_activePointers.length == 2 && !_scrollMode) {
                        _scrollMode = true;
                        _controlConn.sendEvent(2, 0, 0, 0); // cancel pending tap/drag
                      }
                    },
                    onPointerMove: (e) {
                      final prev = _activePointers[e.pointer];
                      _activePointers[e.pointer] = e.localPosition;
                      if (!_scrollMode && _activePointers.length == 1) {
                        final nx = e.localPosition.dx / constraints.maxWidth;
                        final ny = e.localPosition.dy / constraints.maxHeight;
                        _controlConn.sendEvent(0, 0, nx, ny); // move
                      } else if (_scrollMode && _activePointers.length >= 2 && prev != null) {
                        final dy = (e.localPosition.dy - prev.dy) / constraints.maxHeight;
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
                    child: Texture(textureId: _textureId!),
                  ),
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

          // Status bar superior
          Positioned(
            top: 0, left: 0, right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 10,
                left: 20, right: 20, bottom: 10,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent],
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 10, height: 10,
                    decoration: BoxDecoration(
                      color: _textureId != null
                          ? Colors.green
                          : (_isConnected ? Colors.orange : Colors.red),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(_status, style: const TextStyle(color: Colors.white, fontSize: 14)),
                ],
              ),
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
                child: const Text('Conectar', style: TextStyle(fontSize: 16)),
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
