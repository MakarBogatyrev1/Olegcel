import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../services/webrtc_service.dart';
import '../services/signaling_service.dart';

class VideoCallScreen extends StatefulWidget {
  final String roomId;
  final String userName;
  final bool isInitiator;

  const VideoCallScreen({
    super.key,
    required this.roomId,
    required this.userName,
    required this.isInitiator,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  final WebRTCService _webRTCService = WebRTCService();
  final SignalingService _signalingService = SignalingService();
  
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  
  bool _isAudioEnabled = true;
  bool _isVideoEnabled = true;
  bool _isFrontCamera = true;
  bool _isConnecting = true;
  bool _hasRemoteVideo = false;

  @override
  void initState() {
    super.initState();
    _initRenderers();
    _initializeCall();
  }

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  Future<void> _initializeCall() async {
    try {
      // Получаем локальный поток
      final localStream = await _webRTCService.getLocalStream();
      _localRenderer.srcObject = localStream;
      
      // Настраиваем обработчики событий WebRTC
      _webRTCService.onLocalStreamReady = () {
        setState(() {});
      };
      
      _webRTCService.onRemoteStreamAdded = (id, stream) {
        setState(() {
          _remoteRenderer.srcObject = stream;
          _hasRemoteVideo = true;
          _isConnecting = false;
        });
      };
      
      _webRTCService.onRemoteStreamRemoved = (id) {
        setState(() {
          _remoteRenderer.srcObject = null;
          _hasRemoteVideo = false;
        });
      };
      
      _webRTCService.onIceCandidate = (candidate) {
        _webRTCService.handleIceCandidate(candidate);
      };
      
      // Настраиваем обработчик сигнального сервера
      _signalingService.onMessage = (data) {
        _handleSignalingMessage(data);
      };
      
      // Если инициатор, создаем предложение
      if (widget.isInitiator) {
        final offer = await _webRTCService.createOffer();
        _signalingService.sendMessage({
          ...offer,
          'roomId': widget.roomId,
        });
      }
      
      setState(() {
        _isConnecting = false;
      });
      
    } catch (e) {
      setState(() {
        _isConnecting = false;
      });
      
      _showErrorDialog('Ошибка подключения', e.toString());
    }
  }

  void _handleSignalingMessage(Map<String, dynamic> data) async {
    switch (data['type']) {
      case 'offer':
        await _webRTCService.handleOffer(data);
        break;
        
      case 'answer':
        await _webRTCService.handleAnswer(data);
        break;
        
      case 'candidate':
        await _webRTCService.addIceCandidate(data['candidate']);
        break;
        
      case 'peer_left':
        _showPeerLeftDialog();
        break;
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showPeerLeftDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Собеседник покинул чат'),
          content: const Text('Звонок завершен'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _webRTCService.dispose();
    _signalingService.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Удаленное видео
          Container(
            color: Colors.black,
            child: _hasRemoteVideo
                ? RTCVideoView(
                    _remoteRenderer,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  )
                : _buildWaitingScreen(),
          ),
          
          // Локальное видео
          if (_localRenderer.srcObject != null)
            Positioned(
              top: 40,
              right: 20,
              child: Container(
                width: 120,
                height: 160,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: RTCVideoView(
                    _localRenderer,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  ),
                ),
              ),
            ),
          
          // Информация о комнате
          Positioned(
            top: 40,
            left: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Комната: ${widget.roomId}',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
          
          // Индикатор подключения
          if (_isConnecting)
            const Positioned(
              top: 100,
              left: 0,
              right: 0,
              child: Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 10),
                    Text(
                      'Подключение...',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          
          // Панель управления
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildControlButton(
                  icon: _isAudioEnabled ? Icons.mic : Icons.mic_off,
                  color: _isAudioEnabled ? Colors.blue : Colors.red,
                  onPressed: () {
                    setState(() {
                      _isAudioEnabled = !_isAudioEnabled;
                      _webRTCService.toggleAudio(_isAudioEnabled);
                    });
                  },
                ),
                _buildControlButton(
                  icon: _isVideoEnabled ? Icons.videocam : Icons.videocam_off,
                  color: _isVideoEnabled ? Colors.blue : Colors.red,
                  onPressed: () {
                    setState(() {
                      _isVideoEnabled = !_isVideoEnabled;
                      _webRTCService.toggleVideo(_isVideoEnabled);
                    });
                  },
                ),
                _buildControlButton(
                  icon: Icons.switch_camera,
                  color: Colors.blue,
                  onPressed: () {
                    setState(() {
                      _isFrontCamera = !_isFrontCamera;
                      _webRTCService.switchCamera();
                    });
                  },
                ),
                _buildControlButton(
                  icon: Icons.call_end,
                  color: Colors.red,
                  onPressed: () {
                    _webRTCService.hangUp();
                    _signalingService.sendMessage({
                      'type': 'leave',
                      'roomId': widget.roomId,
                    });
                    _signalingService.disconnect();
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaitingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.person,
            size: 100,
            color: Colors.grey,
          ),
          const SizedBox(height: 20),
          Text(
            widget.isInitiator
                ? 'Ожидание подключения...'
                : 'Подключение к собеседнику...',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon, color: color),
        iconSize: 30,
        onPressed: onPressed,
      ),
    );
  }
}