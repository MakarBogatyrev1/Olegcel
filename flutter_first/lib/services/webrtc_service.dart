import 'dart:async';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'signaling_service.dart';

class WebRTCService {
  static final WebRTCService _instance = WebRTCService._internal();
  factory WebRTCService() => _instance;
  WebRTCService._internal();

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  final Map<String, MediaStream> _remoteStreams = {};
  
  // Конфигурация ICE серверов
  final Map<String, dynamic> _configuration = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      {'urls': 'stun:stun2.l.google.com:19302'},
      {'urls': 'stun:stun3.l.google.com:19302'},
      {'urls': 'stun:stun4.l.google.com:19302'},
    ]
  };

  // События
  Function()? onLocalStreamReady;
  Function(String, MediaStream)? onRemoteStreamAdded;
  Function(String)? onRemoteStreamRemoved;
  Function(RTCIceCandidate)? onIceCandidate;

  // Получение локального видео и аудио
  Future<MediaStream> getLocalStream() async {
    if (_localStream != null) return _localStream!;
    
    try {
      final Map<String, dynamic> mediaConstraints = {
        'audio': true,
        'video': {
          'facingMode': 'user',
          'width': 640,
          'height': 480,
        }
      };
      
      _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      
      if (onLocalStreamReady != null) {
        onLocalStreamReady!();
      }
      
      return _localStream!;
    } catch (e) {
      print('Error accessing media devices: $e');
      rethrow;
    }
  }

  // Создание peer connection - ИСПРАВЛЕНО для правильной версии API
  Future<RTCPeerConnection> createPeerConnection([Map<String, dynamic>? configuration]) async {
    try {
      // Правильный способ создания peer connection в текущей версии
      _peerConnection = await createPeerConnection(_configuration);
      
      // Добавляем локальный поток - используем правильный метод
      if (_localStream != null) {
        // В некоторых версиях API нужно добавлять каждый трек отдельно
        _localStream!.getTracks().forEach((track) {
          _peerConnection!.addTrack(track, _localStream!);
        });
      }
      
      // Обработка ICE кандидатов
      _peerConnection!.onIceCandidate = (candidate) {
        print('onIceCandidate: ${candidate.candidate}');
        if (onIceCandidate != null) {
          onIceCandidate!(candidate);
        }
      };
      
      // Обработка удаленных потоков - используем onTrack вместо onAddStream
      _peerConnection!.onTrack = (event) {
        print('onTrack: ${event.track.kind}');
        if (event.streams.isNotEmpty) {
          final stream = event.streams[0];
          _remoteStreams[stream.id] = stream;
          if (onRemoteStreamAdded != null) {
            onRemoteStreamAdded!(stream.id, stream);
          }
        }
      };
      
      return _peerConnection!;
    } catch (e) {
      print('Error creating peer connection: $e');
      rethrow;
    }
  }

  // Создание предложения (для инициатора звонка)
  Future<Map<String, dynamic>> createOffer() async {
    try {
      if (_peerConnection == null) {
        await createPeerConnection();
      }
      
      RTCSessionDescription description = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(description);
      
      return {
        'type': 'offer',
        'sdp': description.sdp,
      };
    } catch (e) {
      print('Error creating offer: $e');
      rethrow;
    }
  }

  // Обработка предложения (для получателя)
  Future<void> handleOffer(Map<String, dynamic> offer) async {
    try {
      if (_peerConnection == null) {
        await createPeerConnection();
      }
      
      await _peerConnection!.setRemoteDescription(
        RTCSessionDescription(offer['sdp'], 'offer')
      );
      
      RTCSessionDescription answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);
      
      SignalingService().sendMessage({
        'type': 'answer',
        'sdp': answer.sdp,
      });
    } catch (e) {
      print('Error handling offer: $e');
      rethrow;
    }
  }

  // Обработка ответа
  Future<void> handleAnswer(Map<String, dynamic> answer) async {
    try {
      await _peerConnection!.setRemoteDescription(
        RTCSessionDescription(answer['sdp'], 'answer')
      );
    } catch (e) {
      print('Error handling answer: $e');
      rethrow;
    }
  }

  // Обработка ICE кандидатов
  void handleIceCandidate(RTCIceCandidate candidate) {
    SignalingService().sendMessage({
      'type': 'candidate',
      'candidate': {
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      },
    });
  }

  // Добавление ICE кандидата
  Future<void> addIceCandidate(Map<String, dynamic> candidateMap) async {
    try {
      if (_peerConnection == null) return;
      
      RTCIceCandidate candidate = RTCIceCandidate(
        candidateMap['candidate'],
        candidateMap['sdpMid'],
        candidateMap['sdpMLineIndex'],
      );
      await _peerConnection!.addCandidate(candidate);
      print('ICE candidate added successfully');
    } catch (e) {
      print('Error adding ICE candidate: $e');
    }
  }

  // Переключение камеры
  Future<void> switchCamera() async {
    try {
      if (_localStream != null) {
        await Helper.switchCamera(_localStream as MediaStreamTrack);
      }
    } catch (e) {
      print('Error switching camera: $e');
    }
  }

  // Включение/выключение аудио
  void toggleAudio(bool enabled) {
    if (_localStream != null) {
      _localStream!.getAudioTracks().forEach((track) {
        track.enabled = enabled;
      });
    }
  }

  // Включение/выключение видео
  void toggleVideo(bool enabled) {
    if (_localStream != null) {
      _localStream!.getVideoTracks().forEach((track) {
        track.enabled = enabled;
      });
    }
  }

  // Получение первого удаленного потока
  MediaStream? get firstRemoteStream {
    if (_remoteStreams.isNotEmpty) {
      return _remoteStreams.values.first;
    }
    return null;
  }

  // Завершение звонка
  void hangUp() {
    try {
      if (_peerConnection != null) {
        _peerConnection!.close();
      }
    } catch (e) {
      print('Error closing peer connection: $e');
    }
    _peerConnection = null;
    _remoteStreams.clear();
  }

  // Освобождение ресурсов
  void dispose() {
    try {
      if (_localStream != null) {
        _localStream!.dispose();
      }
      if (_peerConnection != null) {
        _peerConnection!.dispose();
      }
    } catch (e) {
      print('Error disposing resources: $e');
    }
    _localStream = null;
    _peerConnection = null;
    _remoteStreams.clear();
  }
}