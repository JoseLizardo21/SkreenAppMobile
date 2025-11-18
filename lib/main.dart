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

    // Suscribirse al stream de frames sin bloquear
    frameSub = client!.frames.listen(
      (frame) {
        if (!mounted) return;

        _processFrame(frame);
      },
      onError: (error) {
        print("Error recibiendo frames: $error");
        if (mounted) {
          setState(() {
            isConnected = false;
            currentFrame = null;
          });
        }
      },
      onDone: () {
        print("Conexión cerrada");
        if (mounted) {
          setState(() {
            isConnected = false;
            currentFrame = null;
          });
        }
      },
    );
  }

  void _processFrame(ImageFrame frame) {
    final rgba = convertBGRAtoRGBA(frame.bgra);

    try {
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

          uiImage?.dispose();
          setState(() {
            uiImage = image;
            frameWidth = frame.width;
            frameHeight = frame.height;
          });
        },
      );
    } catch (e) {
      print("Error procesando frame: $e");
    }
  }

  // Convierte BGRA a RGBA (o simplemente retorna como está si ya es RGBA)
  Uint8List convertBGRAtoRGBA(Uint8List bgra) {
    final rgba = Uint8List(bgra.length);
    for (int i = 0; i < bgra.length; i += 4) {
      // BGRA -> RGBA: intercambia B y R
      rgba[i] = bgra[i + 2];     // R (posición 0)
      rgba[i + 1] = bgra[i + 1]; // G (posición 1)
      rgba[i + 2] = bgra[i];     // B (posición 2)
      rgba[i + 3] = bgra[i + 3]; // A (posición 3)
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
                child: const Text("Iniciar"),
              )
            else if (uiImage != null && frameWidth != null && frameHeight != null)
              Container(
                color: Colors.black,
                child: RawImage(
                  image: uiImage,
                  fit: BoxFit.contain,
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
                padding: const EdgeInsets.only(top: 20),
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
                  child: const Text("Detener"),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
