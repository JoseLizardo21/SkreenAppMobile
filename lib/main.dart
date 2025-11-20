import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:skreen_app_mobile/services/socket_service.dart';

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
  TcpFrameClient? client;
  Uint8List? currentFrame;
  int? frameWidth;
  int? frameHeight;
  bool isConnected = false;
  StreamSubscription? frameSub;
  ui.Image? uiImage;
  bool isProcessing = false;

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
        _processFrame(frame);
      },
      onError: (error) {
        print("❌ Error recibiendo frames: $error");
        if (mounted) {
          setState(() {
            isConnected = false;
            currentFrame = null;
          });
        }
      },
      onDone: () {
        print("🔌 Conexión cerrada");
        if (mounted) {
          setState(() {
            isConnected = false;
            currentFrame = null;
          });
        }
      },
    );
  }

  void _processFrame(ImageFrame frame) async {
    if (isProcessing) return;
    isProcessing = true;

    print("🎨 Procesando frame ${frame.width}x${frame.height}, ${frame.rgb.length} bytes");

    // Convertir RGB a RGBA (agregar canal alpha)
    final rgba = convertRGBtoRGBA(frame.rgb);

    ui.decodeImageFromPixels(
      rgba,
      frame.width,
      frame.height,
      ui.PixelFormat.rgba8888,
      (image) {
        if (!mounted) {
          image.dispose();
          return;
        }

        print("✅ Frame decodificado: ${image.width}x${image.height}");

        uiImage?.dispose();
        setState(() {
          uiImage = image;
          frameWidth = frame.width;
          frameHeight = frame.height;
        });

        Future.delayed(const Duration(milliseconds: 33), () {
          isProcessing = false;
        });
      },
    );
  }

  // Convierte RGB (3 bytes) a RGBA (4 bytes)
  Uint8List convertRGBtoRGBA(Uint8List rgb) {
    final pixelCount = rgb.length ~/ 3;
    final rgba = Uint8List(pixelCount * 4);
    
    for (int i = 0; i < pixelCount; i++) {
      final rgbIndex = i * 3;
      final rgbaIndex = i * 4;
      
      rgba[rgbaIndex] = rgb[rgbIndex];         // R
      rgba[rgbaIndex + 1] = rgb[rgbIndex + 1]; // G
      rgba[rgbaIndex + 2] = rgb[rgbIndex + 2]; // B
      rgba[rgbaIndex + 3] = 255;               // A (opaco)
    }
    
    return rgba;
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
                      currentFrame = null;
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