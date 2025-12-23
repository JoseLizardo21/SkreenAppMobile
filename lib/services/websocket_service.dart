import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'dart:convert';

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();

  WebSocketChannel? _channel;
  String? _serverUrl;
  bool _isConnected = false;

  // ========== NUEVO: Callbacks para WebRTC ==========
  Function(String type, String sdp)? onSDPReceived;
  Function(int mlineIndex, String candidate)? onICECandidateReceived;

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
      print('✅ Conectado a WebSocket: $url');

      // ========== NUEVO: Procesar mensajes WebRTC ==========
      _channel!.stream.listen(
        _handleMessage,
        onError: (error) {
          print('❌ Error en WebSocket: $error');
          _isConnected = false;
        },
        onDone: () {
          print('🔌 WebSocket cerrado');
          _isConnected = false;
        },
      );
    } catch (e) {
      _isConnected = false;
      print('❌ Error al conectar a WebSocket: $e');
      rethrow;
    }
  }

  // ========== NUEVO: Procesar mensajes entrantes ==========
  void _handleMessage(dynamic message) {
    try {
      final data = jsonDecode(message);
      final type = data['type'] as String;

      print('📨 Mensaje recibido tipo: $type');

      // Mensajes WebRTC
      if (type == 'offer' || type == 'answer') {
        final sdp = data['data'] as String;
        onSDPReceived?.call(type, sdp);
        return;
      }

      if (type == 'candidate') {
        final mlineIndex = data['mlineIndex'] as int;
        final candidate = data['data'] as String;
        onICECandidateReceived?.call(mlineIndex, candidate);
        return;
      }

      // Otros mensajes (tu lógica existente)
      print('💬 Mensaje genérico: $message');
    } catch (e) {
      print('⚠️ Mensaje no JSON: $message');
    }
  }

  Future<void> registerAsFlutter() async {
    if (_channel != null) {
      _channel!.sink.add('register_flutter');
      print('📝 Registrado como cliente Flutter');
    }
  }

  void sendMessage(dynamic message) {
    if (_channel != null && _isConnected) {
      _channel!.sink.add(message);
      print('📤 Mensaje enviado: $message');
    } else {
      print('❌ No conectado al servidor WebSocket');
    }
  }

  // ========== NUEVO: Métodos específicos para WebRTC ==========

  void sendSDP(String type, String sdp) {
    final message = jsonEncode({'type': type, 'data': sdp});
    sendMessage(message);
    print('📤 SDP enviado: $type');
  }

  void sendICECandidate(int mlineIndex, String candidate) {
    final message = jsonEncode({
      'type': 'candidate',
      'mlineIndex': mlineIndex,
      'data': candidate,
    });
    sendMessage(message);
    print('📤 ICE candidate enviado (mline: $mlineIndex)');
  }

  void sendData(Map<String, dynamic> data) {
    sendMessage(jsonEncode(data));
  }

  void sendImage(List<int> imageBytes) {
    if (_channel != null && _isConnected) {
      _channel!.sink.add(imageBytes);
      print('🖼️ Imagen enviada: ${imageBytes.length} bytes');
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
      print('🔌 Desconectado del servidor WebSocket');
    }
  }
}
