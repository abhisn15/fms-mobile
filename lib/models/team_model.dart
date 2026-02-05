class TeamSummary {
  final String id;
  final String name;
  final String leaderName;
  final int memberCount;
  final List<TeamMember> members;

  TeamSummary({
    required this.id,
    required this.name,
    required this.leaderName,
    required this.memberCount,
    this.members = const [],
  });

  factory TeamSummary.fromJson(Map<String, dynamic> json) {
    final membersRaw = json['members'];
    final members = (membersRaw is List)
        ? membersRaw
            .where((e) => e is Map)
            .map((e) => TeamMember.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList()
        : <TeamMember>[];

    return TeamSummary(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '(Tanpa Nama Team)',
      leaderName: json['leader'] is Map
          ? (json['leader']['name']?.toString() ?? 'Tanpa Leader')
          : json['leaderName']?.toString() ?? 'Tanpa Leader',
      memberCount: json['memberCount'] is int
          ? json['memberCount'] as int
          : int.tryParse(json['memberCount']?.toString() ?? '') ?? members.length,
      members: members,
    );
  }
}

class TeamMember {
  final String id;
  final String name;
  final String? email;
  final String? externalId;
  final String? phone;
  final String? teamName;
  final String? leaderName;
  final String? title;
  final String? avatarColor;
  final String? photoUrl;
  final String? positionName;
  final String? siteName;

  TeamMember({
    required this.id,
    required this.name,
    this.email,
    this.externalId,
    this.phone,
    this.teamName,
    this.leaderName,
    this.title,
    this.avatarColor,
    this.photoUrl,
    this.positionName,
    this.siteName,
  });

  factory TeamMember.fromJson(Map<String, dynamic> json) {
    final user = json['user'] is Map ? Map<String, dynamic>.from(json['user'] as Map) : json;
    return TeamMember(
      id: user['id']?.toString() ?? json['userId']?.toString() ?? json['id']?.toString() ?? '',
      name: user['name']?.toString() ?? json['userName']?.toString() ?? json['name']?.toString() ?? '-',
      email: user['email']?.toString(),
      externalId: user['externalId']?.toString(),
      phone: user['phone']?.toString(),
      teamName: json['teamName']?.toString() ?? user['team']?.toString(),
      leaderName: json['leaderName']?.toString(),
      title: user['title']?.toString() ?? user['positionName']?.toString(),
      avatarColor: user['avatarColor']?.toString(),
      photoUrl: user['photoUrl']?.toString(),
      positionName: user['positionName']?.toString() ?? user['position']?.toString(),
      siteName: user['siteName']?.toString() ??
          (user['site'] is Map ? user['site']['name']?.toString() : user['site']?.toString()) ??
          json['siteName']?.toString(),
    );
  }
}
