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
  final String? positionId;
  final String? siteId;
  final Position? position;
  final Site? site;
  final bool? hasPassword; // Indicates if user has set a password
  final bool? needsPasswordChange; // Indicates if user is still using default password

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
    this.positionId,
    this.siteId,
    this.position,
    this.site,
    this.hasPassword,
    this.needsPasswordChange,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    // Ensure name is never null - use email prefix as fallback
    final name = json['name'] as String?;
    final email = json['email'] as String? ?? '';
    final displayName = (name != null && name.trim().isNotEmpty) 
        ? name 
        : (email.isNotEmpty ? email.split('@')[0] : 'User');
    
    return User(
      id: json['id'] as String? ?? '',
      name: displayName,
      email: email,
      role: json['role'] as String? ?? 'karyawan',
      team: json['team'] as String?,
      title: json['title'] as String?,
      avatarColor: json['avatarColor'] as String?,
      photoUrl: json['photoUrl'] as String?,
      externalId: json['externalId'] as String? ?? '',
      positionId: json['positionId'] as String?,
      siteId: json['siteId'] as String?,
      position: json['position'] != null ? Position.fromJson(json['position']) : null,
      site: json['site'] != null ? Site.fromJson(json['site']) : null,
      hasPassword: json['hasPassword'] as bool?,
      needsPasswordChange: json['needsPasswordChange'] as bool?,
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
      'positionId': positionId,
      'siteId': siteId,
      'position': position?.toJson(),
      'site': site?.toJson(),
      'hasPassword': hasPassword,
      'needsPasswordChange': needsPasswordChange,
    };
  }
}

class Position {
  final String id;
  final String positionId;
  final String name;

  Position({
    required this.id,
    required this.positionId,
    required this.name,
  });

  factory Position.fromJson(Map<String, dynamic> json) {
    return Position(
      id: json['id'] as String? ?? '',
      positionId: json['positionId'] as String? ?? '',
      name: json['name'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'positionId': positionId,
      'name': name,
    };
  }
}

class Site {
  final String id;
  final String siteId;
  final String name;

  Site({
    required this.id,
    required this.siteId,
    required this.name,
  });

  factory Site.fromJson(Map<String, dynamic> json) {
    return Site(
      id: json['id'] as String? ?? '',
      siteId: json['siteId'] as String? ?? '',
      name: json['name'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'siteId': siteId,
      'name': name,
    };
  }
}

