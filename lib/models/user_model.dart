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
    // Ensure name is never null - use email prefix as fallback
    final name = json['name'] as String?;
    final email = json['email'] as String? ?? '';
    final displayName = (name != null && name.trim().isNotEmpty) 
        ? name 
        : (email.isNotEmpty ? email.split('@')[0] : 'User');
    
    return User(
      id: json['id'] as String,
      name: displayName,
      email: email,
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

