import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_webrtc/flutter_webrtc.dart';

class WebrtcConnection {
  final String host;

  WebrtcConnection({this.host = '127.0.0.1'});

  Socket? _signalingSocket;
  StreamSubscription<List<int>>? _signalingSub;
  RTCPeerConnection? _pc;
  bool _rendererInitialized = false;

  final RTCVideoRenderer renderer = RTCVideoRenderer();
  void Function(RTCPeerConnectionState state)? onConnectionState;

  Future<void> connect() async {
    if (!_rendererInitialized) {
      await renderer.initialize();
      _rendererInitialized = true;
    }

    // Sin STUN/TURN: en cable todo el tráfico va por el túnel adb (loopback,
    // forzado a ICE-TCP); en WiFi es LAN directa entre dispositivos, sin NAT
    // de por medio, así que tampoco hace falta STUN/TURN.
    _pc = await createPeerConnection({'iceServers': <Map<String, dynamic>>[]});

    _pc!.onTrack = (RTCTrackEvent event) {
      if (event.track.kind == 'video' && event.streams.isNotEmpty) {
        renderer.srcObject = event.streams[0];
      }
    };

    _pc!.onIceCandidate = (RTCIceCandidate candidate) {
      _send({
        'type': 'ice',
        'candidate': candidate.candidate,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      });
    };

    _pc!.onConnectionState = (state) {
      onConnectionState?.call(state);
    };

    _signalingSocket = await Socket.connect(host, 9002);
    _signalingSocket!.setOption(SocketOption.tcpNoDelay, true);

    final buffer = StringBuffer();
    _signalingSub = _signalingSocket!.listen(
      (data) {
        buffer.write(utf8.decode(data, allowMalformed: true));
        final parts = buffer.toString().split('\n');
        buffer.clear();
        if (parts.last.isNotEmpty) buffer.write(parts.last);
        for (final line in parts.sublist(0, parts.length - 1)) {
          _handleSignalingLine(line.trim());
        }
      },
      onError: (_) {},
      cancelOnError: true,
    );
  }

  void _send(Map<String, dynamic> message) {
    _signalingSocket?.write('${jsonEncode(message)}\n');
  }

  Future<void> _handleSignalingLine(String line) async {
    final pc = _pc;
    if (line.isEmpty || pc == null) return;
    try {
      final msg = jsonDecode(line) as Map<String, dynamic>;
      switch (msg['type']) {
        case 'offer':
          await pc.setRemoteDescription(
              RTCSessionDescription(msg['sdp'] as String, 'offer'));
          final answer = await pc.createAnswer();
          await pc.setLocalDescription(answer);
          _send({'type': 'answer', 'sdp': answer.sdp});
          break;
        case 'ice':
          await pc.addCandidate(RTCIceCandidate(
            msg['candidate'] as String?,
            '',
            msg['sdpMLineIndex'] as int?,
          ));
          break;
      }
    } catch (_) {}
  }

  Future<void> disconnect() async {
    await _signalingSub?.cancel();
    _signalingSub = null;
    _signalingSocket?.destroy();
    _signalingSocket = null;
    await _pc?.close();
    await _pc?.dispose();
    _pc = null;
    renderer.srcObject = null;
  }

  Future<void> dispose() async {
    await disconnect();
    await renderer.dispose();
  }
}
