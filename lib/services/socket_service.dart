import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

class TcpFrameClient {
  Socket? socket;

  Future<void> connect() async {
    socket = await Socket.connect("127.0.0.1", 9000);
    print("📡 Conectado al servidor!");

    // Enviar información del cliente al servidor
    await sendClientInfo();
  }

  Future<void> sendClientInfo() async {
    if (socket == null) {
      print("❌ Socket no inicializado");
      return;
    }

    try {
      final String deviceName = Platform.localHostname;

      // Obtener resolución FÍSICA real (en píxeles físicos)
      final ui.Size physicalSize = ui.window.physicalSize;
      final int screenWidth = physicalSize.width.toInt();
      final int screenHeight = physicalSize.height.toInt();

      print("🖥️  Enviando info al servidor: $deviceName ${screenWidth}x${screenHeight}");

      // Serializar según protocolo del servidor C++:
      // [1 byte: tipo] [2 bytes: nombre_len] [nombre_len bytes: nombre] [4 bytes: width] [4 bytes: height]

      final BytesBuilder data = BytesBuilder();

      // 1. Tipo = 1 (ClientInfo)
      data.addByte(1);

      // 2. Longitud del nombre (2 bytes, big-endian)
      final Uint8List nameUtf8 = utf8.encode(deviceName);
      final int nameLen = nameUtf8.length;
      final ByteData lenBytes = ByteData(2);
      lenBytes.setUint16(0, nameLen, Endian.big);
      data.add(lenBytes.buffer.asUint8List());

      // 3. Nombre del dispositivo
      data.add(nameUtf8);

      // 4. Ancho de pantalla (4 bytes, big-endian)
      final ByteData widthBytes = ByteData(4);
      widthBytes.setUint32(0, screenWidth, Endian.big);
      data.add(widthBytes.buffer.asUint8List());

      // 5. Alto de pantalla (4 bytes, big-endian)
      final ByteData heightBytes = ByteData(4);
      heightBytes.setUint32(0, screenHeight, Endian.big);
      data.add(heightBytes.buffer.asUint8List());

      // Enviar datos
      socket!.add(data.toBytes());
      await socket!.flush();

      print("✅ Información enviada al servidor");
    } catch (e) {
      print("❌ Error enviando información: $e");
    }
  }

  Stream<ImageFrame> get frames async* {
    final buffer = BytesBuilder();

    await for (final data in socket!) {
      print("📦 Recibido chunk: ${data.length} bytes");
      buffer.add(data);

      while (buffer.length >= 12) {
        final bytes = buffer.toBytes();
        final header = ByteData.sublistView(bytes, 0, 12);

        // Leer header (big-endian porque usamos htonl en C++)
        final jpegSize = header.getUint32(0, Endian.big);
        final width = header.getUint32(4, Endian.big);
        final height = header.getUint32(8, Endian.big);

        print("🖼️ Header: ${width}x${height}, JPEG: $jpegSize bytes");

        // Verificar que tenemos todo el frame
        final totalSize = 12 + jpegSize;
        if (buffer.length < totalSize) {
          print("⏳ Esperando más datos... tengo ${buffer.length}/$totalSize");
          break;
        }

        // Extraer datos JPEG comprimidos
        final jpegData = Uint8List.fromList(bytes.sublist(12, totalSize));

        // Limpiar buffer
        buffer.clear();
        if (bytes.length > totalSize) {
          buffer.add(bytes.sublist(totalSize));
        }

        print("✅ Frame JPEG extraído, enviando al procesador");
        yield ImageFrame(width, height, jpegData);
      }
    }
  }
}

class ImageFrame {
  final int width;
  final int height;
  final Uint8List jpegData;  // Datos JPEG comprimidos

  ImageFrame(this.width, this.height, this.jpegData);
}