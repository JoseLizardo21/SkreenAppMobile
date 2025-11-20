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
        final dataSize = header.getUint32(0, Endian.big);
        final width = header.getUint32(4, Endian.big);
        final height = header.getUint32(8, Endian.big);

        print("🖼️ Header: ${width}x${height}, data: $dataSize bytes");

        // Verificar que tenemos todo el frame
        final totalSize = 12 + dataSize;
        if (buffer.length < totalSize) {
          print("⏳ Esperando más datos... tengo ${buffer.length}/$totalSize");
          break;
        }

        // Extraer pixels RGB
        final rgbPixels = Uint8List.fromList(bytes.sublist(12, totalSize));

        // Validar tamaño esperado (RGB = 3 bytes por pixel)
        final expectedSize = width * height * 3;
        if (dataSize != expectedSize) {
          print("⚠️ Warning: tamaño inesperado. Esperado: $expectedSize, recibido: $dataSize");
        }

        // Limpiar buffer
        buffer.clear();
        if (bytes.length > totalSize) {
          buffer.add(bytes.sublist(totalSize));
        }

        yield ImageFrame(width, height, rgbPixels);
      }
    }
  }
}

class ImageFrame {
  final int width;
  final int height;
  final Uint8List rgb;  // Cambiado de 'bgra' a 'rgb'

  ImageFrame(this.width, this.height, this.rgb);
}