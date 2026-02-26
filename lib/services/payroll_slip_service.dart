import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../config/api_config.dart';
import '../models/payroll_slip_model.dart';
import 'api_service.dart';

class PayrollSlipService {
  final ApiService _apiService = ApiService();

  Future<List<PayrollSlip>> getPayrollSlips() async {
    final response = await _apiService.get(ApiConfig.essPayrollSlips);
    if (response.statusCode != 200) {
      final message = response.data is Map<String, dynamic>
          ? (response.data['message']?.toString() ?? 'Gagal memuat slip gaji')
          : 'Gagal memuat slip gaji';
      throw Exception(message);
    }

    final payload = response.data;
    if (payload is! Map<String, dynamic>) {
      return [];
    }
    final rawData = payload['data'];
    if (rawData is! List) {
      return [];
    }

    return rawData
        .whereType<Map<String, dynamic>>()
        .map(PayrollSlip.fromJson)
        .where((item) => item.id.isNotEmpty)
        .toList();
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
