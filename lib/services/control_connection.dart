import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

class ControlConnection {
  Socket? _socket;
  Socket? _statusSocket;
  StreamSubscription<List<int>>? _statusSub;
  void Function()? onStreamStopped;

  Future<void> connect() async {
    _socket = await Socket.connect('127.0.0.1', 9003);
    _socket!.setOption(SocketOption.tcpNoDelay, true);
    _connectStatus();
  }

  Future<void> _connectStatus() async {
    try {
      _statusSocket = await Socket.connect('127.0.0.1', 9004);
      final buffer = StringBuffer();
      _statusSub = _statusSocket!.listen(
        (data) {
          buffer.write(utf8.decode(data, allowMalformed: true));
          final parts = buffer.toString().split('\n');
          buffer.clear();
          if (parts.last.isNotEmpty) buffer.write(parts.last);
          for (final line in parts.sublist(0, parts.length - 1)) {
            _handleStatusLine(line.trim());
          }
        },
        onDone: () => _statusSocket = null,
        onError: (_) => _statusSocket = null,
        cancelOnError: true,
      );
    } catch (_) {}
  }

  void _handleStatusLine(String line) {
    if (line.isEmpty) return;
    try {
      final msg = jsonDecode(line) as Map<String, dynamic>;
      if (msg['type'] == 'stream_stopped') {
        onStreamStopped?.call();
      }
    } catch (_) {}
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
    _statusSub?.cancel();
    _statusSocket?.destroy();
    _statusSub = null;
    _statusSocket = null;
    _socket?.destroy();
    _socket = null;
  }
}
