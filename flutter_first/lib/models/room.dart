class User {
  final String id;
  final String name;
  bool isAudioEnabled;
  bool isVideoEnabled;

  User({
    required this.id,
    required this.name,
    this.isAudioEnabled = true,
    this.isVideoEnabled = true,
  });
}

class Room {
  final String id;
  final String name;
  List<User> participants;

  Room({
    required this.id,
    required this.name,
    this.participants = const [],
  });
}