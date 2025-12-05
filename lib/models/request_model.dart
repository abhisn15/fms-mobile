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
    return LeaveRequest(
      id: json['id'] as String,
      userId: json['userId'] as String,
      type: json['type'] as String,
      status: json['status'] as String,
      reason: json['reason'] as String,
      startDate: json['startDate'] as String,
      endDate: json['endDate'] as String,
      reviewerId: json['reviewerId'] as String?,
      createdAt: json['createdAt'] as String,
      updatedAt: json['updatedAt'] as String,
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
    return RequestPayload(
      requests: (json['requests'] as List<dynamic>?)
              ?.map((e) => LeaveRequest.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

