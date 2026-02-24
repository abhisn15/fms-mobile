import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../config/api_config.dart';
import '../models/checkpoint_model.dart';
import 'api_service.dart';

class CheckpointService {
  final ApiService _apiService = ApiService();

  /// Mendapatkan checkpoint aktif untuk user hari ini
  Future<EssCheckpointPayload> getActiveCheckpoint({String? date}) async {
    try {
      final params = <String, String>{};
      if (date != null) params['date'] = date;
      final queryString = params.isNotEmpty
          ? '?${params.entries.map((e) => '${e.key}=${e.value}').join('&')}'
          : '';

      debugPrint('[CheckpointService] Loading checkpoints...');
      final response = await _apiService.get(
        '${ApiConfig.essCheckpoints}$queryString',
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data['data'];
        if (data is Map<String, dynamic>) {
          final payload = EssCheckpointPayload.fromJson(data);
          debugPrint(
            '[CheckpointService] hasCheckpoint: ${payload.hasCheckpoint}, items: ${payload.progress?.length ?? 0}',
          );
          return payload;
        }
      }
      return EssCheckpointPayload(hasCheckpoint: false);
    } catch (e) {
      debugPrint('[CheckpointService] Error loading checkpoints: $e');
      return EssCheckpointPayload(hasCheckpoint: false);
    }
  }

  /// Menyelesaikan satu checkpoint item (before + after photos + GPS).
  /// Mendukung single (photoBefore/photoAfter) atau multiple (photosBefore/photosAfter).
  Future<Map<String, dynamic>> completeCheckpoint({
    required String itemId,
    File? photoBefore,
    File? photoAfter,
    List<File>? photosBefore,
    List<File>? photosAfter,
    String? templateId,
    String? notes,
    String? date,
    double? latitude,
    double? longitude,
    double? accuracy,
  }) async {
    try {
      final formDataMap = <String, dynamic>{'itemId': itemId};
      if (templateId != null && templateId.isNotEmpty) {
        formDataMap['templateId'] = templateId;
      }
      if (date != null) formDataMap['date'] = date;
      if (notes != null && notes.isNotEmpty) formDataMap['notes'] = notes;
      if (latitude != null) formDataMap['latitude'] = latitude.toString();
      if (longitude != null) formDataMap['longitude'] = longitude.toString();
      if (accuracy != null) formDataMap['accuracy'] = accuracy.toString();

      final formData = FormData.fromMap(formDataMap);
      final beforeList = photosBefore?.isNotEmpty == true
          ? photosBefore!
          : (photoBefore != null ? [photoBefore] : <File>[]);
      final afterList = photosAfter?.isNotEmpty == true
          ? photosAfter!
          : (photoAfter != null ? [photoAfter] : <File>[]);
      for (final f in beforeList) {
        formData.files.add(
          MapEntry('photoBefore', await MultipartFile.fromFile(f.path)),
        );
      }
      for (final f in afterList) {
        formData.files.add(
          MapEntry('photoAfter', await MultipartFile.fromFile(f.path)),
        );
      }

      debugPrint('[CheckpointService] Completing checkpoint: $itemId');
      final response = await _apiService.postFormData(
        ApiConfig.essCheckpointComplete,
        formData,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('[CheckpointService] Checkpoint completed');
        return {
          'success': true,
          'data': response.data['data'],
          'message': response.data['message'] ?? 'Checkpoint selesai',
        };
      } else {
        throw Exception(
          response.data['message'] ?? 'Gagal menyelesaikan checkpoint',
        );
      }
    } catch (e) {
      debugPrint('[CheckpointService] Error: $e');
      return {
        'success': false,
        'message': e.toString().replaceAll('Exception: ', ''),
      };
    }
  }

  /// Mendapatkan site feature flags
  Future<Map<String, dynamic>> getSiteFlags() async {
    try {
      final response = await _apiService.get(ApiConfig.essSiteFlags);
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data['data'];
        if (data is Map<String, dynamic>) {
          return data['flags'] is Map<String, dynamic>
              ? data['flags'] as Map<String, dynamic>
              : {};
        }
      }
      return {};
    } catch (e) {
      debugPrint('[CheckpointService] Error loading site flags: $e');
      return {};
    }
  }
}
