/// Model untuk Checkpoint Template dan Progress di Daily Activity

class CheckpointTemplateItem {
  final String id;
  final String name;
  final int order;
  final bool requiresPhoto;
  /// Jika true, karyawan bisa upload banyak foto before/after; jika false hanya 1 before & 1 after.
  final bool allowMultiplePhotos;
  final String? description;

  CheckpointTemplateItem({
    required this.id,
    required this.name,
    required this.order,
    required this.requiresPhoto,
    this.allowMultiplePhotos = false,
    this.description,
  });

  factory CheckpointTemplateItem.fromJson(Map<String, dynamic> json) {
    return CheckpointTemplateItem(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      order: json['order'] is int ? json['order'] as int : 0,
      requiresPhoto: json['requiresPhoto'] == true,
      allowMultiplePhotos: json['allowMultiplePhotos'] == true,
      description: json['description'] as String?,
    );
  }
}

class CheckpointTemplate {
  final String id;
  final String name;
  final String? description;
  final String positionId;
  final String? positionName;
  final String? siteId;
  final String? siteName;
  final List<CheckpointTemplateItem> items;
  final bool isMandatoryOrder;
  final bool isActive;

  CheckpointTemplate({
    required this.id,
    required this.name,
    this.description,
    required this.positionId,
    this.positionName,
    this.siteId,
    this.siteName,
    required this.items,
    required this.isMandatoryOrder,
    required this.isActive,
  });

  factory CheckpointTemplate.fromJson(Map<String, dynamic> json) {
    final itemsRaw = json['items'];
    List<CheckpointTemplateItem> items = [];
    if (itemsRaw is List) {
      items = itemsRaw
          .whereType<Map<String, dynamic>>()
          .map((e) => CheckpointTemplateItem.fromJson(e))
          .toList()
        ..sort((a, b) => a.order.compareTo(b.order));
    }

    return CheckpointTemplate(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      positionId: json['positionId'] as String? ?? '',
      positionName: json['positionName'] as String?,
      siteId: json['siteId'] as String?,
      siteName: json['siteName'] as String?,
      items: items,
      isMandatoryOrder: json['isMandatoryOrder'] == true,
      isActive: json['isActive'] != false,
    );
  }
}

class CheckpointProgressItem {
  final String id;
  final String name;
  final int order;
  final bool completed;
  final String? timestamp;
  final String? photoBeforeUrl;
  final String? photoAfterUrl;
  final List<String>? photoBeforeUrls;
  final List<String>? photoAfterUrls;
  final String? notes;
  final double? latitude;
  final double? longitude;
  final double? accuracy;

  CheckpointProgressItem({
    required this.id,
    required this.name,
    required this.order,
    required this.completed,
    this.timestamp,
    this.photoBeforeUrl,
    this.photoAfterUrl,
    this.photoBeforeUrls,
    this.photoAfterUrls,
    this.notes,
    this.latitude,
    this.longitude,
    this.accuracy,
  });

  List<String> get beforePhotoUrls {
    if (photoBeforeUrls != null && photoBeforeUrls!.isNotEmpty) return photoBeforeUrls!;
    if (photoBeforeUrl != null) return [photoBeforeUrl!];
    return [];
  }

  List<String> get afterPhotoUrls {
    if (photoAfterUrls != null && photoAfterUrls!.isNotEmpty) return photoAfterUrls!;
    if (photoAfterUrl != null) return [photoAfterUrl!];
    return [];
  }

  factory CheckpointProgressItem.fromJson(Map<String, dynamic> json) {
    List<String>? beforeUrls;
    List<String>? afterUrls;
    if (json['photoBeforeUrls'] is List) {
      beforeUrls = (json['photoBeforeUrls'] as List).whereType<String>().toList();
    }
    if (json['photoAfterUrls'] is List) {
      afterUrls = (json['photoAfterUrls'] as List).whereType<String>().toList();
    }
    return CheckpointProgressItem(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      order: json['order'] is int ? json['order'] as int : 0,
      completed: json['completed'] == true,
      timestamp: json['timestamp'] as String?,
      photoBeforeUrl: json['photoBeforeUrl'] as String?,
      photoAfterUrl: json['photoAfterUrl'] as String?,
      photoBeforeUrls: beforeUrls,
      photoAfterUrls: afterUrls,
      notes: json['notes'] as String?,
      latitude: json['latitude'] is num ? (json['latitude'] as num).toDouble() : null,
      longitude: json['longitude'] is num ? (json['longitude'] as num).toDouble() : null,
      accuracy: json['accuracy'] is num ? (json['accuracy'] as num).toDouble() : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'order': order,
      'completed': completed,
      if (timestamp != null) 'timestamp': timestamp,
      if (photoBeforeUrl != null) 'photoBeforeUrl': photoBeforeUrl,
      if (photoAfterUrl != null) 'photoAfterUrl': photoAfterUrl,
      if (photoBeforeUrls != null) 'photoBeforeUrls': photoBeforeUrls,
      if (photoAfterUrls != null) 'photoAfterUrls': photoAfterUrls,
      if (notes != null) 'notes': notes,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (accuracy != null) 'accuracy': accuracy,
    };
  }
}

class EssCheckpointPayload {
  final bool hasCheckpoint;
  final CheckpointTemplate? template;
  final String? assignmentId;
  final List<CheckpointProgressItem>? progress;
  final String? activityId;

  EssCheckpointPayload({
    required this.hasCheckpoint,
    this.template,
    this.assignmentId,
    this.progress,
    this.activityId,
  });

  int get completedCount => progress?.where((p) => p.completed).length ?? 0;
  int get totalCount => progress?.length ?? 0;
  double get percentage => totalCount > 0 ? completedCount / totalCount : 0;

  factory EssCheckpointPayload.fromJson(Map<String, dynamic> json) {
    List<CheckpointProgressItem>? progress;
    if (json['progress'] is List) {
      progress = (json['progress'] as List)
          .whereType<Map<String, dynamic>>()
          .map((e) => CheckpointProgressItem.fromJson(e))
          .toList()
        ..sort((a, b) => a.order.compareTo(b.order));
    }

    return EssCheckpointPayload(
      hasCheckpoint: json['hasCheckpoint'] == true,
      template: json['template'] is Map<String, dynamic>
          ? CheckpointTemplate.fromJson(json['template'] as Map<String, dynamic>)
          : null,
      assignmentId: json['assignmentId'] as String?,
      progress: progress,
      activityId: json['activityId'] as String?,
    );
  }
}
