import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../config/api_config.dart';
import '../models/payroll_slip_model.dart';
import 'api_service.dart';

class PayrollSlipListResult {
  final List<PayrollSlip> items;
  final int page;
  final int limit;
  final int total;
  final int totalPages;

  const PayrollSlipListResult({
    required this.items,
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
  });
}

class PayrollSlipService {
  final ApiService _apiService = ApiService();

  Future<PayrollSlipListResult> getPayrollSlips({
    int page = 1,
    int limit = 20,
    String? search,
    String? periodStart,
    String? periodEnd,
  }) async {
    final queryParameters = <String, dynamic>{'page': page, 'limit': limit};
    if (search != null && search.trim().isNotEmpty) {
      queryParameters['search'] = search.trim();
    }
    if (periodStart != null && periodStart.trim().isNotEmpty) {
      queryParameters['periodStart'] = periodStart.trim();
    }
    if (periodEnd != null && periodEnd.trim().isNotEmpty) {
      queryParameters['periodEnd'] = periodEnd.trim();
    }

    final response = await _apiService.get(
      ApiConfig.essPayrollSlips,
      queryParameters: queryParameters,
    );
    if (response.statusCode != 200) {
      final message = response.data is Map<String, dynamic>
          ? (response.data['message']?.toString() ?? 'Gagal memuat slip gaji')
          : 'Gagal memuat slip gaji';
      throw Exception(message);
    }

    final payload = response.data;
    if (payload is! Map<String, dynamic>) {
      return const PayrollSlipListResult(
        items: [],
        page: 1,
        limit: 20,
        total: 0,
        totalPages: 0,
      );
    }
    final rawData = payload['data'];
    if (rawData is! List) {
      return const PayrollSlipListResult(
        items: [],
        page: 1,
        limit: 20,
        total: 0,
        totalPages: 0,
      );
    }

    final items = rawData
        .whereType<Map<String, dynamic>>()
        .map(PayrollSlip.fromJson)
        .where((item) => item.id.isNotEmpty)
        .toList();

    final pagination = payload['pagination'];
    if (pagination is! Map<String, dynamic>) {
      return PayrollSlipListResult(
        items: items,
        page: 1,
        limit: items.length,
        total: items.length,
        totalPages: items.isEmpty ? 0 : 1,
      );
    }

    int parseInt(dynamic value, int fallback) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? fallback;
      return fallback;
    }

    final parsedPage = parseInt(pagination['page'], 1);
    final parsedLimit = parseInt(pagination['limit'], limit);
    final parsedTotal = parseInt(pagination['total'], items.length);
    final parsedTotalPages = parseInt(
      pagination['totalPages'],
      parsedTotal == 0 ? 0 : 1,
    );

    return PayrollSlipListResult(
      items: items,
      page: parsedPage <= 0 ? 1 : parsedPage,
      limit: parsedLimit <= 0 ? limit : parsedLimit,
      total: parsedTotal < 0 ? 0 : parsedTotal,
      totalPages: parsedTotalPages < 0 ? 0 : parsedTotalPages,
    );
  }

  Future<Uint8List> getPayrollSlipPdfBytes(PayrollSlip slip) async {
    final endpoint = slip.fileUrl.trim().isNotEmpty
        ? slip.fileUrl
        : ApiConfig.essPayrollSlipPdf(slip.id);

    final response = await _apiService.get(
      endpoint,
      responseType: ResponseType.bytes,
    );

    if (response.statusCode != 200) {
      final message = response.data is Map<String, dynamic>
          ? (response.data['message']?.toString() ??
                'Gagal memuat file slip gaji')
          : 'Gagal memuat file slip gaji';
      throw Exception(message);
    }

    final data = response.data;
    if (data is Uint8List) return data;
    if (data is List<int>) return Uint8List.fromList(data);
    throw Exception('Format file slip gaji tidak valid');
  }
}
