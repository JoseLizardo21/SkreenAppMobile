import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:media_kit/src/player/native/player/real.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
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
  late final Player _player;
  late final VideoController _videoController;

  bool _isPlaying = false;
  bool _isConnected = false;
  String _status = 'Desconectado';

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    WakelockPlus.enable();

    _player = Player(
      configuration: const PlayerConfiguration(
        bufferSize: 64 * 1024,
        logLevel: MPVLogLevel.warn,
      ),
    );
    _videoController = VideoController(_player);

    _player.stream.playing.listen((playing) {
      debugPrint('[SkreenApp] playing=$playing');
      if (mounted) setState(() {
        _isPlaying = playing;
        if (playing) _status = 'Transmitiendo';
      });
    });
    _player.stream.error.listen((error) {
      debugPrint('[SkreenApp] ERROR: $error');
      if (mounted) setState(() => _status = 'Error: $error');
    });
    _player.stream.buffering.listen((buffering) {
      debugPrint('[SkreenApp] buffering=$buffering');
      if (mounted && !_isPlaying) {
        setState(() => _status = buffering ? 'Buffering...' : 'Conectando...');
      }
    });
    _player.stream.log.listen((log) {
      debugPrint('[mpv] ${log.level}: ${log.text.trim()}');
    });
    _player.stream.completed.listen((completed) {
      debugPrint('[SkreenApp] completed=$completed');
    });
  }

  Future<void> _connect() async {
    debugPrint('[SkreenApp] _connect() iniciado');
    setState(() {
      _isConnected = true;
      _status = 'Conectando...';
    });

    try {
      final native = _player.platform as NativePlayer;
      await native.setProperty('load-unsafe-playlists', 'yes');
      await native.setProperty('cache', 'no');
      await native.setProperty('demuxer', 'lavf');
      await native.setProperty('demuxer-lavf-format', 'mpegts');
      await native.setProperty('demuxer-lavf-probesize', '32768');
      await native.setProperty('demuxer-lavf-analyzeduration', '0.05');
      await native.setProperty('network-timeout', '5');
      await native.setProperty('demuxer-readahead-secs', '0');
      await native.setProperty('video-latency-hacks', 'yes');
      await native.setProperty('vd-lavc-threads', '1');
      await native.setProperty('framedrop', 'vo');
      await native.setProperty('correct-pts', 'no');
      await native.setProperty('stream-buffer-size', '4096');
      await native.setProperty('video-sync', 'desync');
      await native.setProperty('vd-lavc-fast', 'yes');
      await native.setProperty('ao', 'null');
      await native.setProperty('speed', '1.0');
      debugPrint('[SkreenApp] Propiedades mpv configuradas');
    } catch (e) {
      debugPrint('[SkreenApp] setProperty error: $e');
    }

    debugPrint('[SkreenApp] Abriendo stream http://localhost:9002 ...');
    await _player.open(Media('http://localhost:9002'));
    debugPrint('[SkreenApp] player.open() completado');
  }

  Future<void> _disconnect() async {
    debugPrint('[SkreenApp] _disconnect()');
    await _player.stop();
    setState(() {
      _isConnected = false;
      _isPlaying = false;
      _status = 'Desconectado';
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Video siempre presente con tamaño real
          Positioned.fill(
            child: Video(
              controller: _videoController,
              controls: NoVideoControls,
              fit: BoxFit.contain,
            ),
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
                      color: _isPlaying
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
