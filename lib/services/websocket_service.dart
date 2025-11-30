import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();

  WebSocketChannel? _channel;
  String? _serverUrl;
  bool _isConnected = false;

  factory WebSocketService() {
    return _instance;
  }

  WebSocketService._internal();

  bool get isConnected => _isConnected;
  WebSocketChannel? get channel => _channel;

  Future<void> connect(String url) async {
    try {
      _serverUrl = url;
      _channel = WebSocketChannel.connect(Uri.parse(url));
      _isConnected = true;
      print('Conectado a WebSocket: $url');
    } catch (e) {
      _isConnected = false;
      print('Error al conectar a WebSocket: $e');
      rethrow;
    }
  }

  Future<void> registerAsFlutter() async {
    if (_channel != null) {
      _channel!.sink.add('register_flutter');
      print('Registrado como cliente Flutter');
    }
  }

  void sendMessage(dynamic message) {
    if (_channel != null && _isConnected) {
      _channel!.sink.add(message);
      print('Mensaje enviado: $message');
    } else {
      print('No conectado al servidor WebSocket');
    }
  }

  void sendData(Map<String, dynamic> data) {
    sendMessage(data.toString());
  }

  void sendImage(List<int> imageBytes) {
    if (_channel != null && _isConnected) {
      _channel!.sink.add(imageBytes);
      print('Imagen enviada: ${imageBytes.length} bytes');
    }
  }

  Stream get messageStream {
    if (_channel != null) {
      return _channel!.stream;
    }
    return Stream.empty();
  }

  Future<void> disconnect() async {
    if (_channel != null) {
      await _channel!.sink.close(status.goingAway);
      _isConnected = false;
      _channel = null;
      print('Desconectado del servidor WebSocket');
    }
  }
}
