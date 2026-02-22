import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

class SignalingService {
  static final SignalingService _instance = SignalingService._internal();
  factory SignalingService() => _instance;
  SignalingService._internal();

  WebSocketChannel? _channel;
  Function(Map<String, dynamic>)? onMessage;
  Function(dynamic)? onError;
  Function()? onDone;
  String? _roomId;
  bool _isConnected = false;

  Future<void> connect(String signalingServerUrl) async {
    try {
      // Закрываем предыдущее соединение если есть
      if (_channel != null) {
        disconnect();
      }

      _channel = WebSocketChannel.connect(Uri.parse(signalingServerUrl));
      _isConnected = true;
      
      _channel!.stream.listen(
        (message) {
          if (onMessage != null) {
            try {
              // Проверяем тип сообщения
              if (message is String) {
                final data = jsonDecode(message);
                onMessage!(data);
              } else if (message is Map) {
                // Если сообщение уже Map, используем как есть
                onMessage!(message as Map<String, dynamic>);
              } else {
                print('Unknown message type: ${message.runtimeType}');
              }
            } catch (e) {
              print('Error parsing message: $e');
              if (onError != null) {
                onError!('Parse error: $e');
              }
            }
          }
        },
        onError: (error) {
          print('WebSocket error: $error');
          _isConnected = false;
          if (onError != null) {
            onError!(error);
          }
        },
        onDone: () {
          print('WebSocket connection closed');
          _isConnected = false;
          _channel = null;
          if (onDone != null) {
            onDone!();
          }
        },
        cancelOnError: true,
      );
      
      print('Connected to signaling server: $signalingServerUrl');
    } catch (e) {
      print('Signaling connection error: $e');
      _isConnected = false;
      rethrow;
    }
  }

  void sendMessage(Map<String, dynamic> message) {
    if (_channel != null && _isConnected) {
      try {
        // Добавляем roomId в сообщение если есть
        if (_roomId != null && !message.containsKey('roomId')) {
          message['roomId'] = _roomId;
        }
        
        _channel!.sink.add(jsonEncode(message));
        print('Message sent: ${message['type']}');
      } catch (e) {
        print('Error sending message: $e');
        if (onError != null) {
          onError!('Send error: $e');
        }
      }
    } else {
      print('Cannot send message: WebSocket not connected');
      if (onError != null) {
        onError!('Not connected to signaling server');
      }
    }
  }

  void setRoomId(String roomId) {
    _roomId = roomId;
    print('Room ID set: $roomId');
  }

  String? get roomId => _roomId;

  bool get isConnected => _isConnected && _channel != null;

  void disconnect() {
    try {
      _channel?.sink.close();
      print('Signaling service disconnected');
    } catch (e) {
      print('Error during disconnect: $e');
    } finally {
      _channel = null;
      _roomId = null;
      _isConnected = false;
    }
  }

  void reconnect(String signalingServerUrl) {
    disconnect();
    connect(signalingServerUrl);
  }
}