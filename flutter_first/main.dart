import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter + Flask + SQLite',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Click Counter with Database'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _localCounter = 0;
  int _serverTotal = 0;
  String _username = 'test_user';
  String _apiMessage = 'Не подключено к серверу';
  List<dynamic> _history = [];
  List<dynamic> _leaderboard = [];
  Map<String, dynamic> _stats = {};
  bool _isLoading = false;
  bool _isConnected = false;

  // Для Chrome/Edge используйте localhost
  final String baseUrl = 'http://localhost:5000';

  @override
  void initState() {
    super.initState();
    _connectToServer();
  }

  // Подключение к серверу и получение данных
  Future<void> _connectToServer() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/hello'),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _apiMessage = data['message'];
          _stats = data['stats'] ?? {};
          _isConnected = true;
        });
        
        // Загружаем данные пользователя
        await _loadUserData();
        await _loadLeaderboard();
        
        _showSnackBar('✅ Подключено к серверу!');
      } else {
        throw Exception('Failed to connect');
      }
    } catch (e) {
      setState(() {
        _apiMessage = '❌ Ошибка подключения: $e';
        _isConnected = false;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Загрузка данных пользователя
  Future<void> _loadUserData() async {
    if (!_isConnected) return;

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/clicks/$_username'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _serverTotal = data['total_clicks'] ?? 0;
          _history = data['history'] ?? [];
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  // Загрузка таблицы лидеров
  Future<void> _loadLeaderboard() async {
    if (!_isConnected) return;

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/leaderboard'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _leaderboard = data['leaderboard'] ?? [];
        });
      }
    } catch (e) {
      print('Error loading leaderboard: $e');
    }
  }

  // Отправка нажатия на сервер
  Future<void> _sendClickToServer() async {
    if (!_isConnected) {
      _showSnackBar('❌ Нет подключения к серверу');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/click'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': _username,
          'click_count': 1,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _serverTotal = data['user_total'] ?? _serverTotal + 1;
        });
        
        // Обновляем данные
        await _loadUserData();
        await _loadLeaderboard();
        
        _showSnackBar('✅ Нажатие сохранено!');
      } else {
        throw Exception('Failed to save click');
      }
    } catch (e) {
      _showSnackBar('❌ Ошибка: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Локальное нажатие (с сохранением на сервере)
  void _incrementCounter() {
    setState(() {
      _localCounter++;
    });
    _sendClickToServer();
  }

  // Сброс счетчика
  Future<void> _resetCounter() async {
    if (!_isConnected) {
      _showSnackBar('❌ Нет подключения к серверу');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/reset_user/$_username'),
      );

      if (response.statusCode == 200) {
        setState(() {
          _localCounter = 0;
          _serverTotal = 0;
        });
        await _loadUserData();
        await _loadLeaderboard();
        _showSnackBar('✅ Счетчик сброшен');
      } else {
        throw Exception('Failed to reset');
      }
    } catch (e) {
      _showSnackBar('❌ Ошибка: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Смена пользователя
  Future<void> _changeUsername(String newUsername) async {
    setState(() {
      _username = newUsername;
      _isLoading = true;
    });

    await _loadUserData();
    
    setState(() {
      _isLoading = false;
    });
    
    _showSnackBar('👤 Пользователь: $_username');
  }

  // Показать уведомление
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // Форматирование даты
  String _formatDate(String? timestamp) {
    if (timestamp == null) return '';
    try {
      final date = DateTime.parse(timestamp);
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')} ${date.day}.${date.month}.${date.year}';
    } catch (e) {
      return timestamp;
    }
  }

  // Цвет для ранга в таблице лидеров
  Color _getRankColor(int index) {
    switch (index) {
      case 0:
        return Colors.amber;
      case 1:
        return Colors.grey;
      case 2:
        return Colors.brown;
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        title: Text(
          widget.title,
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          // Индикатор подключения
          Container(
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _isConnected ? Colors.green : Colors.red,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _isConnected ? '🟢 Online' : '🔴 Offline',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _connectToServer,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Выбор пользователя
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '👤 Пользователь:',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _username,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12),
                              ),
                              items: ['test_user', 'john', 'jane', 'bob']
                                  .map((user) => DropdownMenuItem(
                                        value: user,
                                        child: Text(user),
                                      ))
                                  .toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  _changeUsername(value);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Карточка со счетчиком
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Text(
                        'Локальный счетчик:',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                      Text(
                        '$_localCounter',
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Divider(),
                      const SizedBox(height: 10),
                      const Text(
                        'Серверный счетчик:',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                      Text(
                        '$_serverTotal',
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _isLoading ? null : _incrementCounter,
                            icon: const Icon(Icons.add),
                            label: const Text('Нажать'),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(120, 50),
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: _isLoading ? null : _resetCounter,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Сброс'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(120, 50),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Статус сервера
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '📊 Статус сервера:',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _apiMessage,
                        style: const TextStyle(fontSize: 14),
                      ),
                      if (_stats.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text('👥 Всего пользователей: ${_stats['total_users'] ?? 0}'),
                        Text('🖱️ Всего нажатий: ${_stats['total_clicks_all'] ?? 0}'),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Таблица лидеров
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '🏆 Таблица лидеров',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      _leaderboard.isEmpty
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(20),
                                child: Text('Нет данных'),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _leaderboard.length,
                              itemBuilder: (context, index) {
                                final item = _leaderboard[index];
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: _getRankColor(index),
                                    child: Text(
                                      '${index + 1}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    item['username'] ?? 'Unknown',
                                    style: const TextStyle(fontWeight: FontWeight.w500),
                                  ),
                                  trailing: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      '${item['total_clicks']} 👆',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // История нажатий - ИСПРАВЛЕНО: Icons.click заменен на Icons.touch_app
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '📜 История нажатий',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      _history.isEmpty
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(20),
                                child: Text('История пуста'),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _history.length > 10 ? 10 : _history.length,
                              itemBuilder: (context, index) {
                                final click = _history[index];
                                return ListTile(
                                  leading: CircleAvatar(
                                    radius: 15,
                                    backgroundColor: Colors.purple.shade100,
                                    child: const Icon(
                                      Icons.touch_app,  // ИСПРАВЛЕНО: было Icons.click
                                      size: 15,
                                      color: Colors.purple,
                                    ),
                                  ),
                                  title: Text(
                                    'Нажатие #${click['id']}',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                  subtitle: Text(
                                    _formatDate(click['timestamp']),
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  trailing: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade50,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      '+${click['click_count']}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green.shade700,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Кнопка обновления
              Center(
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _connectToServer,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Обновить данные'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(200, 50),
                  ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}