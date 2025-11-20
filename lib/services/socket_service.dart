import 'dart:io';
import 'dart:typed_data';

class TcpFrameClient {
  Socket? socket;

  Future<void> connect() async {
    socket = await Socket.connect("127.0.0.1", 9000);
    print("📡 Conectado al servidor!");
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