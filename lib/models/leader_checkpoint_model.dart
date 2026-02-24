class LeaderCheckpointTemplateOption {
  final String id;
  final String name;
  final String? description;

  const LeaderCheckpointTemplateOption({
    required this.id,
    required this.name,
    this.description,
  });

  factory LeaderCheckpointTemplateOption.fromJson(Map<String, dynamic> json) {
    return LeaderCheckpointTemplateOption(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
    );
  }
}

class LeaderCheckpointProgressTask {
  final String id;
  final String name;
  final int order;
  final bool completed;
  final String? timestamp;
  final String? notes;

  const LeaderCheckpointProgressTask({
    required this.id,
    required this.name,
    required this.order,
    required this.completed,
    this.timestamp,
    this.notes,
  });

  factory LeaderCheckpointProgressTask.fromJson(Map<String, dynamic> json) {
    return LeaderCheckpointProgressTask(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      order: (json['order'] as num?)?.toInt() ?? 0,
      completed: json['completed'] == true,
      timestamp: json['timestamp']?.toString(),
      notes: json['notes']?.toString(),
    );
  }
}

class LeaderCheckpointProgressItem {
  final String userId;
  final String userName;
  final String? userExternalId;
  final String? userTeam;
  final String templateId;
  final String templateName;
  final int completedCount;
  final int totalCount;
  final int percentage;
  final List<LeaderCheckpointProgressTask> progress;
  final String? lastActivityTimestamp;

  const LeaderCheckpointProgressItem({
    required this.userId,
    required this.userName,
    this.userExternalId,
    this.userTeam,
    required this.templateId,
    required this.templateName,
    required this.completedCount,
    required this.totalCount,
    required this.percentage,
    required this.progress,
    this.lastActivityTimestamp,
  });

  factory LeaderCheckpointProgressItem.fromJson(Map<String, dynamic> json) {
    final progressRaw = json['progress'];
    final progress = (progressRaw is List)
        ? progressRaw
              .whereType<Map<String, dynamic>>()
              .map(LeaderCheckpointProgressTask.fromJson)
              .toList()
        : <LeaderCheckpointProgressTask>[];

    return LeaderCheckpointProgressItem(
      userId: json['userId']?.toString() ?? '',
      userName: json['userName']?.toString() ?? '',
      userExternalId: json['userExternalId']?.toString(),
      userTeam: json['userTeam']?.toString(),
      templateId: json['templateId']?.toString() ?? '',
      templateName: json['templateName']?.toString() ?? '',
      completedCount: (json['completedCount'] as num?)?.toInt() ?? 0,
      totalCount: (json['totalCount'] as num?)?.toInt() ?? 0,
      percentage: (json['percentage'] as num?)?.toInt() ?? 0,
      progress: progress,
      lastActivityTimestamp: json['lastActivityTimestamp']?.toString(),
    );
  }
}

class LeaderCheckpointMonitoringPagination {
  final int page;
  final int limit;
  final int total;
  final int totalPages;

  const LeaderCheckpointMonitoringPagination({
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
  });

  factory LeaderCheckpointMonitoringPagination.fromJson(
    Map<String, dynamic> json,
  ) {
    return LeaderCheckpointMonitoringPagination(
      page: (json['page'] as num?)?.toInt() ?? 1,
      limit: (json['limit'] as num?)?.toInt() ?? 50,
      total: (json['total'] as num?)?.toInt() ?? 0,
      totalPages: (json['totalPages'] as num?)?.toInt() ?? 1,
    );
  }
}

class LeaderCheckpointMonitoringResult {
  final List<LeaderCheckpointProgressItem> items;
  final LeaderCheckpointMonitoringPagination pagination;

  const LeaderCheckpointMonitoringResult({
    required this.items,
    required this.pagination,
  });

  factory LeaderCheckpointMonitoringResult.fromJson(Map<String, dynamic> json) {
    final itemsRaw = json['items'];
    final items = (itemsRaw is List)
        ? itemsRaw
              .whereType<Map<String, dynamic>>()
              .map(LeaderCheckpointProgressItem.fromJson)
              .toList()
        : <LeaderCheckpointProgressItem>[];

    final paginationRaw = json['pagination'];
    final pagination = paginationRaw is Map<String, dynamic>
        ? LeaderCheckpointMonitoringPagination.fromJson(paginationRaw)
        : const LeaderCheckpointMonitoringPagination(
            page: 1,
            limit: 50,
            total: 0,
            totalPages: 1,
          );

    return LeaderCheckpointMonitoringResult(
      items: items,
      pagination: pagination,
    );
  }
}
