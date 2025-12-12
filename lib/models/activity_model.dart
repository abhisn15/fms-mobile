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
  final String? locationName; // Nama tempat untuk patroli
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
    this.locationName,
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
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      date: json['date'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      sentiment: json['sentiment'] as String? ?? 'netral',
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
      locationName: json['locationName'] as String?,
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
      createdAt: json['createdAt'] as String? ?? '',
      isRead: json['isRead'] as bool?,
      viewsCount: json['viewsCount'] != null ? (json['viewsCount'] as num).toInt() : null,
    );
  }
}

class SecurityCheckpoint {
  final String id;
  final String name;
  final bool completed;
  final String? timestamp; // ISO 8601 timestamp
  final String? photoUrl;
  final String? photoReason; // Alasan/findings (sesuai backend)
  final double? latitude; // Untuk backward compatibility
  final double? longitude; // Untuk backward compatibility
  final Map<String, double>? coordinates; // Format backend: {lat, lng}

  SecurityCheckpoint({
    required this.id,
    required this.name,
    required this.completed,
    this.timestamp,
    this.photoUrl,
    this.photoReason,
    this.latitude,
    this.longitude,
    this.coordinates,
  });

  factory SecurityCheckpoint.fromJson(Map<String, dynamic> json) {
    // Handle coordinates dari backend (bisa {lat, lng} atau langsung latitude/longitude)
    Map<String, double>? coordinates;
    double? lat;
    double? lng;
    
    if (json['coordinates'] != null && json['coordinates'] is Map) {
      final coords = json['coordinates'] as Map<String, dynamic>;
      lat = coords['lat'] != null ? (coords['lat'] as num).toDouble() : null;
      lng = coords['lng'] != null ? (coords['lng'] as num).toDouble() : null;
      if (lat != null && lng != null) {
        coordinates = {'lat': lat, 'lng': lng};
      }
    } else {
      // Backward compatibility: langsung dari latitude/longitude
      lat = json['latitude'] != null ? (json['latitude'] as num).toDouble() : null;
      lng = json['longitude'] != null ? (json['longitude'] as num).toDouble() : null;
      if (lat != null && lng != null) {
        coordinates = {'lat': lat, 'lng': lng};
      }
    }
    
    return SecurityCheckpoint(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      completed: json['completed'] as bool? ?? false,
      timestamp: json['timestamp'] as String?,
      photoUrl: json['photoUrl'] as String?,
      photoReason: json['photoReason'] as String? ?? json['reason'] as String?, // Backward compatibility
      latitude: lat,
      longitude: lng,
      coordinates: coordinates,
    );
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'id': id,
      'name': name,
      'completed': completed,
    };
    
    if (timestamp != null) {
      json['timestamp'] = timestamp;
    }
    
    if (photoUrl != null) {
      json['photoUrl'] = photoUrl;
    }
    
    if (photoReason != null) {
      json['photoReason'] = photoReason; // Backend menggunakan photoReason
    }
    
    // Format coordinates sesuai backend: {lat, lng}
    if (coordinates != null) {
      json['coordinates'] = coordinates;
    } else if (latitude != null && longitude != null) {
      json['coordinates'] = {
        'lat': latitude!,
        'lng': longitude!,
      };
    }
    
    return json;
  }
  
  // Getter untuk backward compatibility
  String? get reason => photoReason;
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

