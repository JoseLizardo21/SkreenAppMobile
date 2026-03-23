import 'dart:io';
import 'dart:typed_data';

class ControlConnection {
  Socket? _socket;

  Future<void> connect() async {
    _socket = await Socket.connect('127.0.0.1', 9003);
    _socket!.setOption(SocketOption.tcpNoDelay, true);
  }

  void sendEvent(int type, int slot, double nx, double ny) {
    final socket = _socket;
    if (socket == null) return;
    final buf = ByteData(13);
    buf.setUint8(0, type);
    buf.setInt32(1, slot, Endian.big);
    buf.setFloat32(5, nx.clamp(-1.0, 1.0), Endian.big);
    buf.setFloat32(9, ny.clamp(-1.0, 1.0), Endian.big);
    socket.add(buf.buffer.asUint8List());
  }

  void disconnect() {
    _socket?.destroy();
    _socket = null;
  }
}
