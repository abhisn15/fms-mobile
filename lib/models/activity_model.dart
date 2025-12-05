class DailyActivity {
  final String id;
  final String userId;
  final String date;
  final String summary;
  final String sentiment; // positif, netral, negatif
  final int focusHours;
  final List<String> blockers;
  final List<String> highlights;
  final List<String> plans;
  final String? notes;
  final List<SecurityCheckpoint>? checkpoints;
  final List<String>? photoUrls;
  final double? latitude;
  final double? longitude;
  final String createdAt;
  final bool? isRead; // Status apakah sudah dibaca oleh admin/supervisor
  final int? viewsCount; // Jumlah admin/supervisor yang sudah melihat

  DailyActivity({
    required this.id,
    required this.userId,
    required this.date,
    required this.summary,
    required this.sentiment,
    required this.focusHours,
    required this.blockers,
    required this.highlights,
    required this.plans,
    this.notes,
    this.checkpoints,
    this.photoUrls,
    this.latitude,
    this.longitude,
    required this.createdAt,
    this.isRead,
    this.viewsCount,
  });

  factory DailyActivity.fromJson(Map<String, dynamic> json) {
    return DailyActivity(
      id: json['id'] as String,
      userId: json['userId'] as String,
      date: json['date'] as String,
      summary: json['summary'] as String,
      sentiment: json['sentiment'] as String,
      focusHours: json['focusHours'] as int? ?? 0,
      blockers: (json['blockers'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      highlights: (json['highlights'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      plans: (json['plans'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      notes: json['notes'] as String?,
      checkpoints: json['checkpoints'] != null
          ? (json['checkpoints'] as List<dynamic>)
              .map((e) => SecurityCheckpoint.fromJson(e as Map<String, dynamic>))
              .toList()
          : null,
      photoUrls: json['photoUrls'] != null
          ? (json['photoUrls'] as List<dynamic>).map((e) => e as String).toList()
          : null,
      latitude: json['latitude'] != null ? (json['latitude'] as num).toDouble() : null,
      longitude: json['longitude'] != null ? (json['longitude'] as num).toDouble() : null,
      createdAt: json['createdAt'] as String,
      isRead: json['isRead'] as bool?,
      viewsCount: json['viewsCount'] != null ? (json['viewsCount'] as num).toInt() : null,
    );
  }
}

class SecurityCheckpoint {
  final String id;
  final String name;
  final bool completed;
  final String? photoUrl;
  final String? reason;
  final double? latitude;
  final double? longitude;

  SecurityCheckpoint({
    required this.id,
    required this.name,
    required this.completed,
    this.photoUrl,
    this.reason,
    this.latitude,
    this.longitude,
  });

  factory SecurityCheckpoint.fromJson(Map<String, dynamic> json) {
    return SecurityCheckpoint(
      id: json['id'] as String,
      name: json['name'] as String,
      completed: json['completed'] as bool? ?? false,
      photoUrl: json['photoUrl'] as String?,
      reason: json['reason'] as String?,
      latitude: json['latitude'] != null ? (json['latitude'] as num).toDouble() : null,
      longitude: json['longitude'] != null ? (json['longitude'] as num).toDouble() : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'completed': completed,
      'photoUrl': photoUrl,
      'reason': reason,
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}

class ActivityPayload {
  final DailyActivity? today;
  final List<DailyActivity> recent;

  ActivityPayload({
    this.today,
    required this.recent,
  });

  factory ActivityPayload.fromJson(Map<String, dynamic> json) {
    // Backend returns { entries: [...], timeline: [...] }
    // We need to convert to { today: ..., recent: [...] }
    final entries = (json['entries'] as List<dynamic>?) ?? [];
    final timeline = (json['timeline'] as List<dynamic>?) ?? [];
    
    // Use entries if available, otherwise use timeline
    final allActivities = entries.isNotEmpty ? entries : timeline;
    
    // Find today's activity
    // Backend date format is YYYY-MM-DD
    final now = DateTime.now();
    final todayDate = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    
    DailyActivity? todayActivity;
    List<DailyActivity> recentActivities = [];
    
    for (final entry in allActivities) {
      try {
        final activity = DailyActivity.fromJson(entry as Map<String, dynamic>);
        // Compare dates (both should be in YYYY-MM-DD format)
        final activityDate = activity.date.split('T')[0]; // Remove time if present
        if (activityDate == todayDate) {
          todayActivity = activity;
        } else {
          recentActivities.add(activity);
        }
      } catch (e) {
        // Skip invalid entries
        continue;
      }
    }
    
    return ActivityPayload(
      today: todayActivity,
      recent: recentActivities,
    );
  }
}

