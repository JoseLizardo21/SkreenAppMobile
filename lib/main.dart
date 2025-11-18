import 'dart:typed_data';
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

  @override
  void dispose() {
    client?.socket?.close();
    super.dispose();
  }

  Future<void> start() async {
    client = TcpFrameClient();
    await client!.connect();

    setState(() {
      isConnected = true;
    });

    // Suscribirse al stream de frames
    await for (final frame in client!.frames) {
      if (!mounted) break;

      setState(() {
        currentFrame = convertBGRAtoRGBA(frame.bgra);
        frameWidth = frame.width;
        frameHeight = frame.height;
      });
    }
  }

  // Convierte BGRA a RGBA
  Uint8List convertBGRAtoRGBA(Uint8List bgra) {
    final rgba = Uint8List(bgra.length);
    for (int i = 0; i < bgra.length; i += 4) {
      // BGRA -> RGBA
      rgba[i] = bgra[i + 2];     // R = B
      rgba[i + 1] = bgra[i + 1]; // G = G
      rgba[i + 2] = bgra[i];     // B = B
      rgba[i + 3] = bgra[i + 3]; // A = A
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
            else if (currentFrame != null && frameWidth != null && frameHeight != null)
              Container(
                color: Colors.black,
                child: Image.memory(
                  currentFrame!,
                  width: frameWidth!.toDouble(),
                  height: frameHeight!.toDouble(),
                  gaplessPlayback: true,
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
                    client?.socket?.close();
                    setState(() {
                      isConnected = false;
                      currentFrame = null;
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
