import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../config/api_config.dart';
import '../models/team_model.dart';
import '../models/shift_model.dart';
import '../models/shift_assignment_model.dart';

class TeamServiceException implements Exception {
  final String message;
  final int? statusCode;
  TeamServiceException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class TeamService {
  final ApiService _apiService = ApiService();

  Future<List<TeamSummary>> getLeaderTeams() async {
    final response = await _apiService.get(ApiConfig.leaderTeams);
    if (response.statusCode == 200) {
      final data = response.data?['data'];
      if (data is List) {
        return data
            .where((e) => e is Map)
            .map((e) => TeamSummary.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
      return [];
    }
    throw TeamServiceException(
      response.data?['message']?.toString() ?? 'Gagal memuat team leader',
      statusCode: response.statusCode,
    );
  }

  Future<List<TeamMember>> getLeaderTeamMembers({
    required String teamId,
    int limit = 100,
    bool fetchAll = true,
  }) async {
    final allMembers = <TeamMember>[];
    var page = 1;

    while (true) {
      final response = await _apiService.get(
        ApiConfig.leaderTeamMembers,
        queryParameters: {
          'teamId': teamId,
          'limit': limit,
          'page': page,
        },
      );

      if (response.statusCode != 200) {
        throw TeamServiceException(
          response.data?['message']?.toString() ?? 'Gagal memuat anggota team',
          statusCode: response.statusCode,
        );
      }

      final data = response.data?['data'];
      if (data is! List || data.isEmpty) {
        break;
      }

      final members = data
          .where((e) => e is Map)
          .map((e) => TeamMember.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      allMembers.addAll(members);

      if (!fetchAll || members.length < limit) {
        break;
      }
      page += 1;
    }

    return allMembers;
  }

  Future<List<TeamSummary>> getMyTeamsWithMembers() async {
    final response = await _apiService.get(ApiConfig.teamMembers);
    if (response.statusCode == 200) {
      final data = response.data?['data'];
      if (data is List) {
        return data
            .where((e) => e is Map)
            .map((e) => TeamSummary.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
      return [];
    }
    throw TeamServiceException(
      response.data?['message']?.toString() ?? 'Gagal memuat data team',
      statusCode: response.statusCode,
    );
  }

  Future<List<DailyShift>> getLeaderShiftMaster() async {
    final response = await _apiService.get(
      ApiConfig.leaderShiftMaster,
      queryParameters: {'scope': 'core'},
    );
    if (response.statusCode != 200) {
      throw TeamServiceException(
        response.data?['message']?.toString() ?? 'Gagal memuat master shift',
        statusCode: response.statusCode,
      );
    }
    final data = response.data?['data'];
    if (data is Map && data['daily'] is List) {
      final list = data['daily'] as List;
      return list
          .where((e) => e is Map)
          .map((e) => DailyShift.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    if (data is List) {
      return data
          .where((e) => e is Map)
          .map((e) => DailyShift.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    return [];
  }

  Future<List<ShiftAssignment>> getLeaderShiftAssignments({
    required String teamId,
    required DateTime startDate,
    required DateTime endDate,
    List<String> ownerIds = const [],
  }) async {
    String formatDate(DateTime date) {
      final year = date.year.toString().padLeft(4, '0');
      final month = date.month.toString().padLeft(2, '0');
      final day = date.day.toString().padLeft(2, '0');
      return '$year-$month-$day';
    }

    final params = <String, dynamic>{
      'teamId': teamId,
      'startDate': formatDate(startDate),
      'endDate': formatDate(endDate),
      'mode': 'schedule',
    };

    if (ownerIds.isNotEmpty) {
      params['ownerIds'] = ownerIds;
    }

    final response = await _apiService.get(ApiConfig.leaderShiftAssignments, queryParameters: params);
    if (response.statusCode != 200) {
      throw TeamServiceException(
        response.data?['message']?.toString() ?? 'Gagal memuat jadwal shift team',
        statusCode: response.statusCode,
      );
    }

    final data = response.data?['data'];
    if (data is List) {
      return data
          .where((e) => e is Map)
          .map((e) => ShiftAssignment.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    return [];
  }

  Future<void> assignShift({
    required String teamId,
    required DateTime date,
    required String dailyShiftId,
    required List<String> ownerIds,
    bool overwrite = false,
  }) async {
    String formatDate(DateTime value) {
      final year = value.year.toString().padLeft(4, '0');
      final month = value.month.toString().padLeft(2, '0');
      final day = value.day.toString().padLeft(2, '0');
      return '$year-$month-$day';
    }

    final response = await _apiService.post(
      ApiConfig.leaderShiftAssignments,
      data: {
        'teamId': teamId,
        'date': formatDate(date),
        'dailyShiftId': dailyShiftId,
        'ownerIds': ownerIds,
        'overwrite': overwrite,
      },
    );

    if (response.statusCode != 200) {
      throw TeamServiceException(
        response.data?['message']?.toString() ?? 'Gagal assign shift',
        statusCode: response.statusCode,
      );
    }
  }

  Future<void> deleteShiftAssignment({
    required String teamId,
    required String assignmentId,
  }) async {
    final response = await _apiService.delete(
      ApiConfig.leaderShiftAssignments,
      data: {
        'teamId': teamId,
        'id': assignmentId,
      },
    );

    if (response.statusCode != 200) {
      throw TeamServiceException(
        response.data?['message']?.toString() ?? 'Gagal menghapus shift',
        statusCode: response.statusCode,
      );
    }
  }
}
