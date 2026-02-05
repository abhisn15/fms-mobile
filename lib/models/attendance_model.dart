import 'package:flutter/foundation.dart';

class AttendanceRecord {
  final String id;
  final String userId;
  final String date;
  final String status; // present, late, absent, leave, sick, remote
  final String? checkIn;
  final String? checkOut;
  final String? shiftId;
  final String? notes;
  final String? photoUrl; // Deprecated: use checkInPhotoUrl and checkOutPhotoUrl instead
  final String? checkInPhotoUrl;
  final String? checkOutPhotoUrl;
  final Location? location; // Deprecated: use checkInLocation and checkOutLocation instead
  final Location? checkInLocation;
  final Location? checkOutLocation;
  final bool isAutoCheckout;
  final bool needsValidation;

  AttendanceRecord({
    required this.id,
    required this.userId,
    required this.date,
    required this.status,
    this.checkIn,
    this.checkOut,
    this.shiftId,
    this.notes,
    this.photoUrl,
    this.checkInPhotoUrl,
    this.checkOutPhotoUrl,
    this.location,
    this.checkInLocation,
    this.checkOutLocation,
    this.isAutoCheckout = false,
    this.needsValidation = false,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      date: json['date'] as String? ?? '',
      status: json['status'] as String? ?? 'absent',
      checkIn: json['checkIn'] as String?,
      checkOut: json['checkOut'] as String?,
      shiftId: json['shiftId'] as String?,
      notes: json['notes'] as String?,
      photoUrl: json['photoUrl'] as String?, // Keep for backward compatibility
      checkInPhotoUrl: json['checkInPhotoUrl'] as String?,
      checkOutPhotoUrl: json['checkOutPhotoUrl'] as String?,
      location: json['location'] != null
          ? Location.fromJson(json['location'] as Map<String, dynamic>)
          : null, // Keep for backward compatibility
      checkInLocation: json['checkInLocation'] != null
          ? Location.fromJson(json['checkInLocation'] as Map<String, dynamic>)
          : null,
      checkOutLocation: json['checkOutLocation'] != null
          ? Location.fromJson(json['checkOutLocation'] as Map<String, dynamic>)
          : null,
      isAutoCheckout: json['isAutoCheckout'] as bool? ?? false,
      needsValidation: json['needsValidation'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'date': date,
      'status': status,
      'checkIn': checkIn,
      'checkOut': checkOut,
      'shiftId': shiftId,
      'notes': notes,
      'photoUrl': photoUrl, // Keep for backward compatibility
      'checkInPhotoUrl': checkInPhotoUrl,
      'checkOutPhotoUrl': checkOutPhotoUrl,
      'location': location?.toJson(), // Keep for backward compatibility
      'checkInLocation': checkInLocation?.toJson(),
      'checkOutLocation': checkOutLocation?.toJson(),
      'isAutoCheckout': isAutoCheckout,
      'needsValidation': needsValidation,
    };
  }
}

class Location {
  final double lat;
  final double lng;

  Location({required this.lat, required this.lng});

  factory Location.fromJson(Map<String, dynamic> json) {
    return Location(
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'lat': lat,
      'lng': lng,
    };
  }
}

class AttendancePayload {
  final List<AttendanceRecord> today;
  final List<AttendanceRecord> recent; // Alias untuk history dari backend

  AttendancePayload({
    required this.today,
    required this.recent,
  });

  factory AttendancePayload.fromJson(Map<String, dynamic> json) {
    // Backend mengembalikan { today: [...], history: [...] }
    // Kita map history ke recent untuk konsistensi dengan Flutter code
    final historyRaw = json['history'];
    final recentRaw = json['recent'];
    final todayRaw = json['today'];

    // Safely extract history list
    List<dynamic> historyList = [];

    if (historyRaw is List<dynamic>) {
      historyList = historyRaw;
    } else if (recentRaw is List<dynamic>) {
      historyList = recentRaw;
    } else if (historyRaw is Map<String, dynamic>) {
      // If history is a Map, try to convert it to a List
      debugPrint('[AttendancePayload] Warning: history is Map, not List. Converting...');
      historyList = historyRaw.values.toList();
    } else if (recentRaw is Map<String, dynamic>) {
      // If recent is a Map, try to convert it to a List
      debugPrint('[AttendancePayload] Warning: recent is Map, not List. Converting...');
      historyList = recentRaw.values.toList();
    } else {
      debugPrint('[AttendancePayload] Warning: Neither history nor recent is a List. history type: ${historyRaw.runtimeType}, recent type: ${recentRaw.runtimeType}');
    }

    // Safely parse history records
    List<AttendanceRecord> parsedHistory = [];
    try {
      parsedHistory = historyList
          .where((e) => e is Map<String, dynamic>)
          .map((e) => AttendanceRecord.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[AttendancePayload] Error parsing history records: $e');
      debugPrint('[AttendancePayload] Raw historyList: $historyList');
    }

    // Safely parse today records (list or single object for backward compatibility)
    List<AttendanceRecord> parsedToday = [];
    try {
      if (todayRaw is List<dynamic>) {
        parsedToday = todayRaw
            .where((e) => e is Map<String, dynamic>)
            .map((e) => AttendanceRecord.fromJson(e as Map<String, dynamic>))
            .toList();
      } else if (todayRaw is Map<String, dynamic>) {
        parsedToday = [AttendanceRecord.fromJson(todayRaw)];
      } else if (todayRaw is Map) {
        parsedToday = [AttendanceRecord.fromJson(Map<String, dynamic>.from(todayRaw))];
      }
    } catch (e) {
      debugPrint('[AttendancePayload] Error parsing today records: $e');
      debugPrint('[AttendancePayload] Raw today: $todayRaw');
    }

    return AttendancePayload(
      today: parsedToday,
      recent: parsedHistory,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'today': today.map((e) => e.toJson()).toList(),
      'recent': recent.map((e) => e.toJson()).toList(),
    };
  }
}
