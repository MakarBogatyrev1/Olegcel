import 'package:flutter/material.dart';
import '../services/signaling_service.dart';
import 'video_call_screen.dart'; // Добавляем этот импорт

class CreateRoomScreen extends StatefulWidget {
  const CreateRoomScreen({super.key});

  @override
  State<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends State<CreateRoomScreen> {
  final TextEditingController _nameController = TextEditingController();
  final SignalingService _signalingService = SignalingService();
  bool _isCreating = false;
  String? _roomId;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _createRoom() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пожалуйста, введите ваше имя')),
      );
      return;
    }

    setState(() {
      _isCreating = true;
    });

    try {
      // Подключаемся к сигнальному серверу
      await _signalingService.connect('ws://212.57.115.62:8080');

      // Создаем комнату
      _signalingService.onMessage = (data) {
        if (data['type'] == 'room_created') {
          setState(() {
            _roomId = data['roomId'];
          });

          // Показываем диалог с ID комнаты
          _showRoomIdDialog(data['roomId']);
        } else if (data['type'] == 'peer_joined') {
          // Кто-то присоединился, начинаем звонок
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => VideoCallScreen(
                roomId: _roomId!,
                userName: _nameController.text,
                isInitiator: true,
              ),
            ),
          );
        }
      };

      // Отправляем запрос на создание комнаты
      _signalingService.sendMessage({'type': 'create_room'});
    } catch (e) {
      setState(() {
        _isCreating = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка подключения: $e')),
      );
    }
  }

  void _showRoomIdDialog(String roomId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Комната создана'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Поделитесь этим ID с семьей:'),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  roomId,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Ожидаем подключения...'),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Создать комнату'),
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
                Icons.video_call,
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
                        enabled: !_isCreating,
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isCreating ? null : _createRoom,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 15),
                          ),
                          child: _isCreating
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
                                    Text('Создание...'),
                                  ],
                                )
                              : const Text('Создать комнату'),
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
