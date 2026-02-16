class TeamTask {
  final String id;
  final String teamId;
  final String assigneeId;
  final String createdById;
  final String title;
  final String? description;
  final DateTime? dueDate;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final TeamTaskUser? assignee;
  final TeamTaskUser? createdBy;
  final TeamTaskTeam? team;

  TeamTask({
    required this.id,
    required this.teamId,
    required this.assigneeId,
    required this.createdById,
    required this.title,
    this.description,
    this.dueDate,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.assignee,
    this.createdBy,
    this.team,
  });

  factory TeamTask.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(String? value) {
      if (value == null || value.trim().isEmpty) return null;
      return DateTime.tryParse(value);
    }

    final assigneeRaw = json['assignee'];
    final createdByRaw = json['createdBy'];
    final teamRaw = json['team'];

    return TeamTask(
      id: json['id']?.toString() ?? '',
      teamId: json['teamId']?.toString() ?? '',
      assigneeId: json['assigneeId']?.toString() ?? '',
      createdById: json['createdById']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString(),
      dueDate: parseDate(json['dueDate']?.toString()),
      status: json['status']?.toString() ?? 'todo',
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.now(),
      assignee: assigneeRaw is Map
          ? TeamTaskUser.fromJson(Map<String, dynamic>.from(assigneeRaw))
          : null,
      createdBy: createdByRaw is Map
          ? TeamTaskUser.fromJson(Map<String, dynamic>.from(createdByRaw))
          : null,
      team: teamRaw is Map
          ? TeamTaskTeam.fromJson(Map<String, dynamic>.from(teamRaw))
          : null,
    );
  }
}

class TeamTaskUser {
  final String id;
  final String name;
  final String? externalId;

  TeamTaskUser({required this.id, required this.name, this.externalId});

  factory TeamTaskUser.fromJson(Map<String, dynamic> json) {
    return TeamTaskUser(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '-',
      externalId: json['externalId']?.toString(),
    );
  }
}

class TeamTaskTeam {
  final String id;
  final String name;

  TeamTaskTeam({required this.id, required this.name});

  factory TeamTaskTeam.fromJson(Map<String, dynamic> json) {
    return TeamTaskTeam(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '(Tanpa Team)',
    );
  }
}
