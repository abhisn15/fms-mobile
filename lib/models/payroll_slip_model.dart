class PayrollSlip {
  final String id;
  final int periodYear;
  final int periodMonth;
  final String periodLabel;
  final String periodKey;
  final int version;
  final String fileUrl;
  final String fileName;
  final int fileSize;
  final String mimeType;
  final DateTime? createdAt;

  const PayrollSlip({
    required this.id,
    required this.periodYear,
    required this.periodMonth,
    required this.periodLabel,
    required this.periodKey,
    required this.version,
    required this.fileUrl,
    required this.fileName,
    required this.fileSize,
    required this.mimeType,
    required this.createdAt,
  });

  String get displayPeriod {
    if (periodLabel.trim().isNotEmpty) return periodLabel.trim();
    if (periodYear <= 0 || periodMonth <= 0) return '-';
    return '$periodYear-${periodMonth.toString().padLeft(2, '0')}';
  }

  factory PayrollSlip.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    return PayrollSlip(
      id: (json['id'] ?? '').toString(),
      periodYear: parseInt(json['periodYear']),
      periodMonth: parseInt(json['periodMonth']),
      periodLabel: (json['periodLabel'] ?? '').toString(),
      periodKey: (json['periodKey'] ?? '').toString(),
      version: parseInt(json['version']),
      fileUrl: (json['fileUrl'] ?? '').toString(),
      fileName: (json['fileName'] ?? '').toString(),
      fileSize: parseInt(json['fileSize']),
      mimeType: (json['mimeType'] ?? '').toString(),
      createdAt: parseDate(json['createdAt']),
    );
  }
}
