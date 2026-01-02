import 'dart:convert';

import 'package:flutter/material.dart';

String _stringValue(dynamic value) {
  if (value == null) return '';
  return value.toString();
}

bool _isPatroliComputed(String? type, String? locationName, double? latitude, double? longitude, List<SecurityCheckpoint>? checkpoints) {
  // Jika type sudah ditentukan dari server, gunakan itu
  if (type == 'patroli') return true;
  if (type == 'daily') return false;

  // Fallback: deteksi berdasarkan data
  return (locationName != null && locationName.isNotEmpty) ||
         (latitude != null && longitude != null) ||
         (checkpoints != null && checkpoints.isNotEmpty);
}

int _intValue(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is num) return value.round();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

double? _doubleValue(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

List<String> _stringListValue(dynamic value) {
  if (value == null) return [];
  if (value is List) {
    return value
        .map((item) => item == null ? '' : item.toString())
        .where((item) => item.isNotEmpty)
        .toList();
  }
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return [];
    if ((trimmed.startsWith('[') && trimmed.endsWith(']')) ||
        (trimmed.startsWith('"') && trimmed.endsWith('"'))) {
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is List) {
          return decoded
              .map((item) => item == null ? '' : item.toString())
              .where((item) => item.isNotEmpty)
              .toList();
        }
        if (decoded is String && decoded.isNotEmpty) {
          return [decoded];
        }
      } catch (_) {}
    }
    return [trimmed];
  }
  return [];
}

List<dynamic>? _listValue(dynamic value) {
  if (value == null) return null;
  if (value is List) return value;
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.startsWith('[') && trimmed.endsWith(']')) {
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is List) return decoded;
      } catch (_) {}
    }
  }
  return null;
}

String _formatDateOnly(DateTime value) {
  final year = value.year.toString().padLeft(4, '0');
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

String _resolveDateOnlyForCompare(DailyActivity activity) {
  final dateValue = activity.date;
  final dateOnly = dateValue.isNotEmpty ? dateValue.split('T').first : '';
  final createdAt = activity.createdAt.isNotEmpty ? DateTime.tryParse(activity.createdAt) : null;
  if (createdAt == null) {
    return dateOnly;
  }
  final createdLocal = createdAt.toLocal();
  final createdDateOnly = _formatDateOnly(createdLocal);
  if (dateOnly.isEmpty) {
    return createdDateOnly;
  }
  final parsedDate = DateTime.tryParse(dateOnly);
  if (parsedDate == null) {
    return createdDateOnly;
  }
  final dateOnlyParsed = DateTime(parsedDate.year, parsedDate.month, parsedDate.day);
  final createdOnly = DateTime(createdLocal.year, createdLocal.month, createdLocal.day);
  final diffDays = (createdOnly.difference(dateOnlyParsed).inDays).abs();
  if (diffDays <= 1) {
    return createdDateOnly;
  }
  return dateOnly;
}

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
  final bool isLocal; // Data lokal (offline) yang belum tersinkron
  final String? type; // 'daily' or 'patroli'
  final bool isPatroli; // Computed property: apakah ini patroli

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
    this.isLocal = false,
    this.type,
  }) : isPatroli = _isPatroliComputed(type, locationName, latitude, longitude, checkpoints);

  factory DailyActivity.fromJson(Map<String, dynamic> json) {
    final checkpointsRaw = _listValue(json['checkpoints']);
    final parsedPhotoUrls = _stringListValue(json['photoUrls']);
    final dateValue = _stringValue(json['date']);
    final createdAtValue = _stringValue(json['createdAt']);
    final summaryValue = _stringValue(json['summary']);
    final sentimentValue = _stringValue(json['sentiment']);

    return DailyActivity(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      date: dateValue,
      summary: summaryValue,
      sentiment: sentimentValue.isNotEmpty ? sentimentValue : 'netral',
      focusHours: _intValue(json['focusHours']),
      blockers: _stringListValue(json['blockers']),
      highlights: _stringListValue(json['highlights']),
      plans: _stringListValue(json['plans']),
      notes: json['notes'] as String?,
      locationName: json['locationName'] as String?,
      checkpoints: checkpointsRaw
          ?.whereType<Map<String, dynamic>>()
          .map((e) => SecurityCheckpoint.fromJson(e))
          .toList(),
      photoUrls: parsedPhotoUrls.isNotEmpty ? parsedPhotoUrls : null,
      latitude: _doubleValue(json['latitude']),
      longitude: _doubleValue(json['longitude']),
      createdAt: createdAtValue,
      isRead: json['isRead'] as bool?,
      viewsCount: json['viewsCount'] != null ? _intValue(json['viewsCount']) : null,
      isLocal: json['isLocal'] == true,
      type: json['type'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'date': date,
      'summary': summary,
      'sentiment': sentiment,
      'focusHours': focusHours,
      'blockers': blockers,
      'highlights': highlights,
      'plans': plans,
      if (notes != null) 'notes': notes,
      if (locationName != null) 'locationName': locationName,
      if (checkpoints != null)
        'checkpoints': checkpoints!.map((item) => item.toJson()).toList(),
      if (photoUrls != null) 'photoUrls': photoUrls,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      'createdAt': createdAt,
      if (isRead != null) 'isRead': isRead,
      if (viewsCount != null) 'viewsCount': viewsCount,
      if (isLocal) 'isLocal': true,
    };
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
    final entries = _listValue(json['entries']) ?? _listValue(json['data']) ?? [];
    final timeline = _listValue(json['timeline']) ?? [];
    
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
        if (entry is! Map<String, dynamic>) {
          continue;
        }
        final activity = DailyActivity.fromJson(entry);
        debugPrint('[ActivityPayload] Parsed activity: ${activity.summary}, type: ${activity.type}, date: ${activity.date}, isPatroli: ${activity.isPatroli}');

        // Compare dates (both should be in YYYY-MM-DD format)
        final activityDate = _resolveDateOnlyForCompare(activity);
        debugPrint('[ActivityPayload] Activity date: $activityDate, today: $todayDate');

        if (activityDate == todayDate) {
          if (todayActivity == null) {
            todayActivity = activity;
            debugPrint('[ActivityPayload] Set as today activity');
          } else {
            recentActivities.add(activity);
            debugPrint('[ActivityPayload] Added to recent (multiple today activities)');
          }
        } else {
          recentActivities.add(activity);
          debugPrint('[ActivityPayload] Added to recent');
        }
      } catch (e) {
        debugPrint('[ActivityPayload] Error parsing activity: $e');
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

