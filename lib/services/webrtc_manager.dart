import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'websocket_service.dart';

class WebRTCManager {
  final WebSocketService _wsService = WebSocketService();

  RTCPeerConnection? _peerConnection;
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();

  bool isConnected = false;

  // Callbacks
  Function()? onVideoStarted;
  Function(String)? onError;
  Function(RTCPeerConnectionState)? onConnectionStateChanged;

  // ========== Inicialización ==========

  Future<void> initialize() async {
    print('🎬 Inicializando WebRTC Manager...');

    // Inicializar renderer
    await remoteRenderer.initialize();

    // Configurar callbacks del WebSocket para recibir señalización
    _wsService.onSDPReceived = _handleRemoteSDP;
    _wsService.onICECandidateReceived = _handleRemoteICECandidate;

    // Crear peer connection
    await _createPeerConnection();

    print('✅ WebRTC Manager inicializado');
  }

  // ========== Crear PeerConnection ==========

  Future<void> _createPeerConnection() async {
    print('🔗 Creando peer connection...');

    final configuration = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
        {'urls': 'stun:stun1.l.google.com:19302'},
      ],
      'sdpSemantics': 'unified-plan',
    };

    final constraints = {
      'mandatory': {},
      'optional': [
        {'DtlsSrtpKeyAgreement': true},
      ],
    };

    _peerConnection = await createPeerConnection(configuration, constraints);

    // ========== Callbacks WebRTC ==========

    // Cuando se recibe video remoto
    _peerConnection!.onTrack = (RTCTrackEvent event) {
      print('📹 Stream de video recibido');
      if (event.streams.isNotEmpty) {
        remoteRenderer.srcObject = event.streams[0];
        isConnected = true;
        onVideoStarted?.call();
      }
    };

    // Cuando se genera un ICE candidate local
    _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
      print('🧊 ICE candidate generado localmente');
      if (candidate.candidate != null) {
        _wsService.sendICECandidate(
          candidate.sdpMLineIndex ?? 0,
          candidate.candidate!,
        );
      }
    };

    // Estado de conexión
    _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
      print('🔄 Estado de conexión: $state');
      onConnectionStateChanged?.call(state);

      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        print('✅ Conexión WebRTC establecida');
        isConnected = true;
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        print('❌ Conexión WebRTC falló');
        isConnected = false;
        onError?.call('Conexión WebRTC falló');
      }
    };

    // Estado ICE
    _peerConnection!.onIceConnectionState = (RTCIceConnectionState state) {
      print('🧊 Estado ICE: $state');
    };

    print('✅ Peer connection creado');
  }

  // ========== Manejo de señalización remota ==========

  Future<void> _handleRemoteSDP(String type, String sdp) async {
    print('📥 Procesando $type remoto...');

    try {
      if (type == 'offer') {
        // Establecer descripción remota
        await _peerConnection!.setRemoteDescription(
          RTCSessionDescription(sdp, 'offer'),
        );

        print('✅ Remote description establecida');

        // Crear respuesta
        RTCSessionDescription answer = await _peerConnection!.createAnswer();

        // Establecer descripción local
        await _peerConnection!.setLocalDescription(answer);

        print('✅ Local description establecida');

        // Enviar respuesta
        _wsService.sendSDP('answer', answer.sdp!);

        print('📤 Answer enviado');
      } else if (type == 'answer') {
        await _peerConnection!.setRemoteDescription(
          RTCSessionDescription(sdp, 'answer'),
        );
        print('✅ Answer procesado');
      }
    } catch (e) {
      print('❌ Error procesando SDP: $e');
      onError?.call('Error procesando SDP: $e');
    }
  }

  Future<void> _handleRemoteICECandidate(
    int mlineIndex,
    String candidate,
  ) async {
    print('🧊 Añadiendo ICE candidate remoto (mline: $mlineIndex)');

    try {
      await _peerConnection!.addCandidate(
        RTCIceCandidate(candidate, '', mlineIndex),
      );
      print('✅ ICE candidate añadido');
    } catch (e) {
      print('❌ Error añadiendo ICE candidate: $e');
    }
  }

  // ========== Cleanup ==========

  Future<void> dispose() async {
    print('🧹 Limpiando WebRTC Manager...');

    await _peerConnection?.close();
    await remoteRenderer.dispose();

    _peerConnection = null;
    isConnected = false;

    print('✅ WebRTC Manager limpiado');
  }
}
