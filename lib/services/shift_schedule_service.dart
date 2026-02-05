import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../config/api_config.dart';
import '../models/shift_assignment_model.dart';

class ShiftScheduleService {
  final ApiService _apiService = ApiService();

  Future<List<ShiftAssignment>> getMyShiftAssignments({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final results = <ShiftAssignment>[];
    int page = 1;
    int totalPages = 1;

    String formatDate(DateTime date) {
      final year = date.year.toString().padLeft(4, '0');
      final month = date.month.toString().padLeft(2, '0');
      final day = date.day.toString().padLeft(2, '0');
      return '$year-$month-$day';
    }

    do {
      final response = await _apiService.get(
        ApiConfig.shiftSchedule,
        queryParameters: {
          'startDate': formatDate(startDate),
          'endDate': formatDate(endDate),
          'page': page,
          'limit': 50,
        },
      );

      if (response.statusCode != 200) {
        final message = response.data?['message'] ?? 'Gagal memuat jadwal shift';
        throw Exception(message.toString());
      }

      final data = response.data?['data'];
      if (data is List) {
        results.addAll(
          data
              .where((e) => e is Map)
              .map((e) => ShiftAssignment.fromJson(Map<String, dynamic>.from(e as Map))),
        );
      }

      final pagination = response.data?['pagination'];
      if (pagination is Map) {
        totalPages = int.tryParse(pagination['totalPages']?.toString() ?? '1') ?? 1;
      } else {
        totalPages = 1;
      }

      page += 1;
    } while (page <= totalPages);

    debugPrint('[ShiftScheduleService] Loaded ${results.length} assignments');
    return results;
  }
}
