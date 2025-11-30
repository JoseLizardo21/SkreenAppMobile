import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:skreen_app_mobile/services/socket_service.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

void main() {
  runApp(const MyApp());
}

// Decodificar JPEG en el hilo principal (no se puede hacer en isolate)
Future<ui.Image> _decodeJpeg(Uint8List jpegData) async {
  final codec = await ui.instantiateImageCodec(jpegData);
  final frame = await codec.getNextFrame();
  return frame.image;
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
  TcpFrameClient? client;
  int? frameWidth;
  int? frameHeight;
  bool isConnected = false;
  StreamSubscription? frameSub;
  ui.Image? uiImage;

  // Cola de frames para evitar descartar frames
  final List<ImageFrame> _frameQueue = [];
  bool _isDecodingFrame = false;

  @override
  void initState() {
    super.initState();
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

  @override
  void dispose() {
    frameSub?.cancel();
    client?.socket?.close();
    uiImage?.dispose();
    super.dispose();
  }

  Future<void> start() async {
    client = TcpFrameClient();
    await client!.connect();

    setState(() {
      isConnected = true;
    });

    // Suscribirse al stream de frames
    frameSub = client!.frames.listen(
      (frame) {
        if (!mounted) return;
        _enqueueFrame(frame);
      },
      onError: (error) {
        print("❌ Error recibiendo frames: $error");
        if (mounted) {
          setState(() {
            isConnected = false;
          });
        }
      },
      onDone: () {
        print("🔌 Conexión cerrada");
        if (mounted) {
          setState(() {
            isConnected = false;
          });
        }
      },
    );
  }

  void _enqueueFrame(ImageFrame frame) {
    // Si la cola está muy llena, descartar el frame más antiguo
    // (el cliente está generando frames más rápido de lo que podemos mostrar)
    if (_frameQueue.length > 2) {
      _frameQueue.removeAt(0);
      print("⚠️ Descartado frame por cola llena");
    }

    // Añadir frame a la cola
    _frameQueue.add(frame);
    print("📥 Frame encolado (cola: ${_frameQueue.length})");

    // Si no estamos decodificando, procesar el siguiente frame
    if (!_isDecodingFrame) {
      _processNextFrame();
    }
  }

  void _processNextFrame() async {
    if (_frameQueue.isEmpty || _isDecodingFrame) return;

    _isDecodingFrame = true;
    final frame = _frameQueue.removeAt(0);

    print("🎨 Procesando frame ${frame.width}x${frame.height}, ${frame.jpegData.length} bytes JPEG (cola: ${_frameQueue.length})");

    try {
      // Decodificar JPEG (debe ser en el hilo principal, Flutter no lo permite en isolates)
      final decodedImage = await _decodeJpeg(frame.jpegData);

      if (!mounted) {
        decodedImage.dispose();
        _isDecodingFrame = false;
        _processNextFrame();
        return;
      }

      print("✅ Frame decodificado: ${decodedImage.width}x${decodedImage.height}");

      uiImage?.dispose();
      setState(() {
        uiImage = decodedImage;
        frameWidth = frame.width;
        frameHeight = frame.height;
      });

      _isDecodingFrame = false;
      _processNextFrame();
    } catch (e) {
      print("❌ Error procesando frame: $e");
      _isDecodingFrame = false;
      _processNextFrame();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            if (!isConnected)
              ElevatedButton(
                onPressed: () {
                  start();
                },
                child: const Text("Iniciar Conexión"),
              )
            else if (uiImage != null && frameWidth != null && frameHeight != null)
              Expanded(
                child: Container(
                  color: Colors.black,
                  child: Center(
                    child: RawImage(
                      image: uiImage,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              )
            else
              const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text("Esperando frames..."),
                ],
              ),
            if (isConnected)
              Padding(
                padding: const EdgeInsets.only(top: 20, bottom: 20),
                child: ElevatedButton(
                  onPressed: () {
                    frameSub?.cancel();
                    client?.socket?.destroy();
                    setState(() {
                      isConnected = false;
                      uiImage = null;
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text("Detener"),
                ),
              ),
          ],
        ),
      ),
    );
  }
}