class LeaveRequest {
  final String id;
  final String userId;
  final String type; // izin, cuti, sakit
  final String status; // pending, approved, rejected, berlangsung
  final String reason;
  final String startDate;
  final String endDate;
  final String? reviewerId;
  final String createdAt;
  final String updatedAt;

  LeaveRequest({
    required this.id,
    required this.userId,
    required this.type,
    required this.status,
    required this.reason,
    required this.startDate,
    required this.endDate,
    this.reviewerId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory LeaveRequest.fromJson(Map<String, dynamic> json) {
    // Safely parse dates - handle both ISO string and Date objects
    String parseDate(dynamic dateValue) {
      if (dateValue == null) return '';
      if (dateValue is String) return dateValue;
      if (dateValue is DateTime) return dateValue.toIso8601String().split('T')[0];
      return dateValue.toString();
    }
    
    // Safely parse ISO string dates
    String parseIsoDate(dynamic dateValue) {
      if (dateValue == null) return '';
      if (dateValue is String) {
        // If it's already an ISO string, return as is
        if (dateValue.contains('T')) return dateValue;
        // If it's just a date string (YYYY-MM-DD), return as is
        return dateValue;
      }
      if (dateValue is DateTime) return dateValue.toIso8601String();
      return dateValue.toString();
    }
    
    return LeaveRequest(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      type: json['type']?.toString() ?? 'izin',
      status: json['status']?.toString() ?? 'pending',
      reason: json['reason']?.toString() ?? '',
      startDate: parseDate(json['startDate']),
      endDate: parseDate(json['endDate']),
      reviewerId: json['reviewerId']?.toString(),
      createdAt: parseIsoDate(json['createdAt']),
      updatedAt: parseIsoDate(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'reason': reason,
      'startDate': startDate,
      'endDate': endDate,
    };
  }
}

class RequestPayload {
  final List<LeaveRequest> requests;

  RequestPayload({required this.requests});

  factory RequestPayload.fromJson(Map<String, dynamic> json) {
    try {
      final requestsData = json['requests'];
      if (requestsData == null) {
        return RequestPayload(requests: []);
      }
      
      if (requestsData is List) {
        return RequestPayload(
          requests: requestsData
              .map((e) {
                try {
                  if (e is Map<String, dynamic>) {
                    return LeaveRequest.fromJson(e);
                  } else if (e is Map) {
                    // Handle case where Map is not typed
                    return LeaveRequest.fromJson(Map<String, dynamic>.from(e));
                  }
                  return null;
                } catch (e) {
                  // Skip invalid entries
                  return null;
                }
              })
              .whereType<LeaveRequest>()
              .toList(),
        );
      }
      
      return RequestPayload(requests: []);
    } catch (e) {
      // Return empty list on any error
      return RequestPayload(requests: []);
    }
  }
}

