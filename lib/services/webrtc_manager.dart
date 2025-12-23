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
      print('📹 ========== onTrack DISPARADO ==========');
      print('📹 Track recibido - kind: ${event.track.kind}');
      print('📹 Track ID: ${event.track.id}');
      print('📹 Track enabled: ${event.track.enabled}');
      print('📹 Número de streams: ${event.streams.length}');

      if (event.streams.isNotEmpty) {
        print('📹 Stream ID: ${event.streams[0].id}');
        print('📹 Tracks en el stream: ${event.streams[0].getTracks().length}');

        remoteRenderer.srcObject = event.streams[0];
        isConnected = true;

        print('✅ srcObject asignado al renderer');
        print('✅ Llamando a onVideoStarted callback...');
        onVideoStarted?.call();
      } else {
        print('⚠️ No hay streams en el evento!');
      }
      print('📹 ========== onTrack FINALIZADO ==========');
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
    print('📥 ========== Procesando SDP $type ==========');
    print('📥 SDP length: ${sdp.length} caracteres');

    try {
      if (type == 'offer') {
        print('📥 Recibido OFFER del servidor');

        // Establecer descripción remota
        await _peerConnection!.setRemoteDescription(
          RTCSessionDescription(sdp, 'offer'),
        );

        print('✅ Remote description establecida');

        // Verificar transceivers
        final transceivers = await _peerConnection!.getTransceivers();
        print('📡 Número de transceivers: ${transceivers.length}');
        for (var transceiver in transceivers) {
          print('   - Tipo: ${transceiver.receiver.track?.kind}');
        }

        // Crear respuesta
        RTCSessionDescription answer = await _peerConnection!.createAnswer();

        // Establecer descripción local
        await _peerConnection!.setLocalDescription(answer);

        print('✅ Local description establecida');
        print('📤 Answer SDP length: ${answer.sdp!.length} caracteres');

        // Enviar respuesta
        _wsService.sendSDP('answer', answer.sdp!);

        print('📤 Answer enviado al servidor');
      } else if (type == 'answer') {
        print('📥 Recibido ANSWER del servidor');
        await _peerConnection!.setRemoteDescription(
          RTCSessionDescription(sdp, 'answer'),
        );
        print('✅ Answer procesado');
      }
      print('========== SDP Procesado Exitosamente ==========');
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
