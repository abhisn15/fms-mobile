import 'dart:io';
import 'package:dio/dio.dart';
import '../config/api_config.dart';
import 'api_service.dart';

class IncidentReportItem {
  final String id;
  final String reportDate;
  final String description;
  final List<String> photoUrls;
  final String createdAt;

  IncidentReportItem({
    required this.id,
    required this.reportDate,
    required this.description,
    required this.photoUrls,
    required this.createdAt,
  });

  factory IncidentReportItem.fromJson(Map<String, dynamic> json) {
    final raw = json['photoUrls'];
    List<String> urls = [];
    if (raw is List) {
      for (final e in raw) {
        if (e != null) urls.add(e.toString());
      }
    }
    return IncidentReportItem(
      id: json['id']?.toString() ?? '',
      reportDate: json['reportDate']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      photoUrls: urls,
      createdAt: json['createdAt']?.toString() ?? '',
    );
  }
}

class IncidentReportListResult {
  final List<IncidentReportItem> data;
  final int page;
  final int limit;
  final int total;
  final int totalPages;

  IncidentReportListResult({
    required this.data,
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
  });
}

class IncidentReportService {
  final ApiService _api = ApiService();

  Future<IncidentReportListResult> getMyReports({int page = 1, int limit = 20}) async {
    final res = await _api.get(
      ApiConfig.incidentReportList(page: page, limit: limit),
    );
    if (res.statusCode != 200) {
      throw Exception(res.data is Map && res.data['message'] != null
          ? res.data['message']
          : 'Gagal memuat laporan');
    }
    final map = res.data is Map ? res.data as Map<String, dynamic> : <String, dynamic>{};
    final list = map['data'] is List ? map['data'] as List : <dynamic>[];
    final pagination = map['pagination'] is Map ? map['pagination'] as Map<String, dynamic> : <String, dynamic>{};
    final items = list
        .map((e) => IncidentReportItem.fromJson(e is Map<String, dynamic> ? e : <String, dynamic>{}))
        .toList();
    return IncidentReportListResult(
      data: items,
      page: (pagination['page'] is int) ? pagination['page'] as int : page,
      limit: (pagination['limit'] is int) ? pagination['limit'] as int : limit,
      total: (pagination['total'] is int) ? pagination['total'] as int : 0,
      totalPages: (pagination['totalPages'] is int) ? pagination['totalPages'] as int : 1,
    );
  }

  Future<IncidentReportItem> submit({
    required DateTime reportDate,
    required String description,
    required List<File> photos,
  }) async {
    final formData = FormData.fromMap({
      'reportDate': reportDate.toIso8601String().split('T').first,
      'description': description.trim(),
    });
    for (final file in photos) {
      if (await file.exists()) {
        formData.files.add(MapEntry(
          'photo',
          await MultipartFile.fromFile(file.path),
        ));
      }
    }
    final res = await _api.postFormData(ApiConfig.incidentReport, formData);
    if (res.statusCode != 200) {
      throw Exception(res.data is Map && res.data['message'] != null
          ? res.data['message']
          : 'Gagal menyimpan laporan');
    }
    final map = res.data is Map ? res.data as Map<String, dynamic> : <String, dynamic>{};
    final data = map['data'] is Map ? map['data'] as Map<String, dynamic> : <String, dynamic>{};
    return IncidentReportItem.fromJson(data);
  }
}
