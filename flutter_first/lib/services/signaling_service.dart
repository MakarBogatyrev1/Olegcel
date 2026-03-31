import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

class SignalingService {
  static final SignalingService _instance = SignalingService._internal();
  factory SignalingService() => _instance;
  SignalingService._internal();

  WebSocketChannel? _channel;
  Function(Map<String, dynamic>)? onMessage;
  String? _roomId;

  Future<void> connect(String signalingServerUrl) async {
    try {
      _channel = WebSocketChannel.connect(Uri.parse(signalingServerUrl));
      
      _channel!.stream.listen(
        (message) {
          if (onMessage != null) {
            try {
              final data = jsonDecode(message as String);
              onMessage!(data);
            } catch (e) {
              print('Error parsing message: $e');
            }
          }
        },
        onError: (error) {
          print('WebSocket error: $error');
        },
        onDone: () {
          print('WebSocket connection closed');
        },
      );
    } catch (e) {
      print('Signaling connection error: $e');
      rethrow;
    }
  }

  void sendMessage(Map<String, dynamic> message) {
    if (_channel != null) {
      _channel!.sink.add(jsonEncode(message));
    } else {
      print('Cannot send message: WebSocket not connected');
    }
  }

  void setRoomId(String roomId) {
    _roomId = roomId;
  }

  String? get roomId => _roomId;

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
    _roomId = null;
  }
}