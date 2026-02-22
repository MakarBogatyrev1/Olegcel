import 'package:flutter/material.dart';
import '../services/signaling_service.dart';
import 'video_call_screen.dart';  // Добавляем этот импорт

class JoinRoomScreen extends StatefulWidget {
  const JoinRoomScreen({super.key});

  @override
  State<JoinRoomScreen> createState() => _JoinRoomScreenState();
}

class _JoinRoomScreenState extends State<JoinRoomScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _roomIdController = TextEditingController();
  final SignalingService _signalingService = SignalingService();
  bool _isJoining = false;

  @override
  void dispose() {
    _nameController.dispose();
    _roomIdController.dispose();
    super.dispose();
  }

  Future<void> _joinRoom() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пожалуйста, введите ваше имя')),
      );
      return;
    }

    if (_roomIdController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пожалуйста, введите ID комнаты')),
      );
      return;
    }

    setState(() {
      _isJoining = true;
    });

    try {
      // Подключаемся к сигнальному серверу
      await _signalingService.connect('ws://212.57.115.62:8080');
      
      _signalingService.onMessage = (data) {
        if (data['type'] == 'room_joined') {
          // Успешно присоединились, начинаем звонок
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => VideoCallScreen(
                roomId: _roomIdController.text,
                userName: _nameController.text,
                isInitiator: false,
              ),
            ),
          );
        } else if (data['type'] == 'error') {
          setState(() {
            _isJoining = false;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['message'] ?? 'Ошибка подключения')),
          );
        }
      };

      // Отправляем запрос на присоединение
      _signalingService.sendMessage({
        'type': 'join_room',
        'roomId': _roomIdController.text.toUpperCase(),
      });
      
    } catch (e) {
      setState(() {
        _isJoining = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка подключения: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Присоединиться к комнате'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue, Colors.lightBlue],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.group_add,
                size: 80,
                color: Colors.white,
              ),
              const SizedBox(height: 40),
              Card(
                elevation: 8,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Ваше имя',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person),
                        ),
                        enabled: !_isJoining,
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _roomIdController,
                        decoration: const InputDecoration(
                          labelText: 'ID комнаты',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.meeting_room),
                          hintText: 'Например: ABC123',
                        ),
                        enabled: !_isJoining,
                        textCapitalization: TextCapitalization.characters,
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isJoining ? null : _joinRoom,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 15),
                          ),
                          child: _isJoining
                              ? const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                    SizedBox(width: 10),
                                    Text('Подключение...'),
                                  ],
                                )
                              : const Text('Присоединиться'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}