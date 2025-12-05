class User {
  final String id;
  final String name;
  final String email;
  final String role;
  final String? team;
  final String? title;
  final String? avatarColor;
  final String? photoUrl;
  final String externalId;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.team,
    this.title,
    this.avatarColor,
    this.photoUrl,
    required this.externalId,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      role: json['role'] as String,
      team: json['team'] as String?,
      title: json['title'] as String?,
      avatarColor: json['avatarColor'] as String?,
      photoUrl: json['photoUrl'] as String?,
      externalId: json['externalId'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role,
      'team': team,
      'title': title,
      'avatarColor': avatarColor,
      'photoUrl': photoUrl,
      'externalId': externalId,
    };
  }
}

