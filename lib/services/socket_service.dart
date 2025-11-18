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
      print(data);
      buffer.add(data);

      while (buffer.length >= 12) {
        final bytes = buffer.toBytes();
        final header = ByteData.sublistView(bytes);

        final packetSize = header.getUint32(0, Endian.little);
        final width = header.getUint32(4, Endian.little);
        final height = header.getUint32(8, Endian.little);

        if (buffer.length < packetSize + 4) break;

        final pixels = bytes.sublist(12, packetSize + 4);

        buffer.clear();
        buffer.add(bytes.sublist(packetSize + 4));

        yield ImageFrame(width, height, pixels);
      }
    }
  }
}

class ImageFrame {
  final int width;
  final int height;
  final Uint8List bgra;

  ImageFrame(this.width, this.height, this.bgra);
}
