import 'package:flutter/foundation.dart';

class AttendanceRecord {
  final String id;
  final String userId;
  final String date;
  final String status; // present, late, absent, leave, sick, remote
  final String? checkIn;
  final String? checkOut;
  final String? originalCheckInDate;
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
    this.originalCheckInDate,
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
      originalCheckInDate: json['originalCheckInDate'] as String?,
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
      'originalCheckInDate': originalCheckInDate,
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
    final latVal = json['lat'];
    final lngVal = json['lng'];
    return Location(
      lat: (latVal is num) ? latVal.toDouble() : (double.tryParse(latVal?.toString() ?? '') ?? 0.0),
      lng: (lngVal is num) ? lngVal.toDouble() : (double.tryParse(lngVal?.toString() ?? '') ?? 0.0),
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

/// Summary for leader attendance report (team monitoring).
class LeaderAttendanceReportSummary {
  final int present;
  final int absent;
  final int late;
  final int leave;
  final int pendingValidation;

  LeaderAttendanceReportSummary({
    required this.present,
    required this.absent,
    required this.late,
    required this.leave,
    required this.pendingValidation,
  });

  factory LeaderAttendanceReportSummary.fromJson(Map<String, dynamic> json) {
    return LeaderAttendanceReportSummary(
      present: (json['present'] as num?)?.toInt() ?? 0,
      absent: (json['absent'] as num?)?.toInt() ?? 0,
      late: (json['late'] as num?)?.toInt() ?? 0,
      leave: (json['leave'] as num?)?.toInt() ?? 0,
      pendingValidation: (json['pendingValidation'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Single log row from leader attendance report (for team monitoring list).
class LeaderAttendanceLogItem {
  final String id;
  final String userId;
  final String date;
  final String status;
  final String? checkIn;
  final String? checkOut;
  final String userName;
  final String? shiftName;

  LeaderAttendanceLogItem({
    required this.id,
    required this.userId,
    required this.date,
    required this.status,
    this.checkIn,
    this.checkOut,
    required this.userName,
    this.shiftName,
  });

  factory LeaderAttendanceLogItem.fromJson(Map<String, dynamic> json) {
    final user = json['user'];
    final name = user is Map ? (user['name'] as String? ?? '') : '';
    return LeaderAttendanceLogItem(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      date: json['date'] as String? ?? '',
      status: json['status'] as String? ?? 'absent',
      checkIn: json['checkIn'] as String?,
      checkOut: json['checkOut'] as String?,
      userName: name,
      shiftName: json['shiftName'] as String?,
    );
  }
}

/// Pagination info for leader attendance report.
class LeaderAttendancePagination {
  final int page;
  final int limit;
  final int total;
  final int totalPages;

  LeaderAttendancePagination({
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
  });

  factory LeaderAttendancePagination.fromJson(Map<String, dynamic> json) {
    return LeaderAttendancePagination(
      page: (json['page'] as num?)?.toInt() ?? 1,
      limit: (json['limit'] as num?)?.toInt() ?? 0,
      total: (json['total'] as num?)?.toInt() ?? 0,
      totalPages: (json['totalPages'] as num?)?.toInt() ?? 1,
    );
  }
}

/// Full leader attendance report (team monitoring).
class LeaderAttendanceReport {
  final LeaderAttendanceReportSummary summary;
  final List<LeaderAttendanceLogItem> logs;
  final LeaderAttendancePagination? pagination;

  LeaderAttendanceReport({
    required this.summary,
    required this.logs,
    this.pagination,
  });

  factory LeaderAttendanceReport.fromJson(Map<String, dynamic> json) {
    final summaryJson = json['summary'];
    final logsRaw = json['logs'];
    final paginationJson = json['pagination'];

    final summary = summaryJson is Map<String, dynamic>
        ? LeaderAttendanceReportSummary.fromJson(summaryJson)
        : LeaderAttendanceReportSummary(
            present: 0,
            absent: 0,
            late: 0,
            leave: 0,
            pendingValidation: 0,
          );

    final logs = logsRaw is List
        ? (logsRaw)
            .where((e) => e is Map<String, dynamic>)
            .map((e) => LeaderAttendanceLogItem.fromJson(e as Map<String, dynamic>))
            .toList()
        : <LeaderAttendanceLogItem>[];

    final pagination = paginationJson is Map<String, dynamic>
        ? LeaderAttendancePagination.fromJson(paginationJson)
        : null;

    return LeaderAttendanceReport(
      summary: summary,
      logs: logs,
      pagination: pagination,
    );
  }
}
