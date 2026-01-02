import 'dart:io';
import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import '../config/api_config.dart';
import '../models/activity_model.dart';
import 'api_service.dart';

class ActivityService {
  final ApiService _apiService = ApiService();

  Future<ActivityPayload> getActivities() async {
    try {
      debugPrint('[ActivityService] Loading activities...');
      final response = await _apiService.get(ApiConfig.activities);
      if (response.statusCode == 200) {
        // Backend returns { entries: [...], timeline: [...] }
        final data = response.data;
        if (data == null) {
          debugPrint('[ActivityService] Data is null');
          throw Exception('Data aktivitas tidak ditemukan');
        }
        final Map<String, dynamic> payloadSource;
        if (data is List) {
          payloadSource = {'entries': data};
        } else if (data is Map<String, dynamic>) {
          payloadSource = data;
        } else {
          debugPrint('[ActivityService] Unexpected data type: ${data.runtimeType}');
          throw Exception('Format data aktivitas tidak valid');
        }
        final entriesCount = payloadSource['entries'] is List
            ? (payloadSource['entries'] as List).length
            : 0;
        debugPrint('[ActivityService] Data received: $entriesCount entries');
        final payload = ActivityPayload.fromJson(payloadSource);
        debugPrint('[ActivityService] Parsed: today=${payload.today != null}, recent=${payload.recent.length}');
        return payload;
      } else {
        // Handle error responses
        debugPrint('[ActivityService] Error status: ${response.statusCode}');
        final errorMessage = response.data is Map && response.data['message'] != null
            ? response.data['message']
            : 'Gagal memuat data aktivitas (status: ${response.statusCode})';
        throw Exception(errorMessage);
      }
    } catch (e) {
      debugPrint('[ActivityService] Error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> submitDailyActivity({
    required String summary,
    String? sentiment,
    int? focusHours,
    List<String>? blockers,
    List<String>? highlights,
    List<String>? plans,
    String? notes,
    List<File> photos = const [],
    String? date,
  }) async {
    try {
      // Prepare form data - hanya summary dan foto
      final Map<String, dynamic> formDataMap = {
        'summary': summary,
        'type': 'daily', // Explicitly set type
        if (date != null) 'date': date,
        if (notes != null) 'notes': notes,
      };

      // Add multiple photos
      final formData = FormData.fromMap(formDataMap);
      if (photos.isNotEmpty) {
        for (final photo in photos) {
          formData.files.add(
            MapEntry(
              'photos', // Backend expects "photos" (plural) for multiple files
              await MultipartFile.fromFile(photo.path),
            ),
          );
        }
      }

      debugPrint('[ActivityService] Submitting daily activity: $summary');
      final response = await _apiService.postFormData(
        ApiConfig.activity,
        formData,
      );

      debugPrint('[ActivityService] Daily activity response: ${response.statusCode}');
      if (response.data != null) {
        debugPrint('[ActivityService] Response data: ${response.data}');
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('[ActivityService] Daily activity submitted successfully');
        return {
          'success': true,
          'data': response.data['data'],
          'message': response.data['message'] ?? 'Aktivitas berhasil disimpan',
        };
      } else {
        debugPrint('[ActivityService] Failed to submit daily activity: ${response.data}');
        throw Exception(response.data['message'] ?? 'Gagal menyimpan aktivitas');
      }
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceAll('Exception: ', ''),
      };
    }
  }

  Future<Map<String, dynamic>> submitPatroli({
    required String summary,
    String? notes,
    List<File> photos = const [],
    double? latitude,
    double? longitude,
    String? locationName,
    String? date,
  }) async {
    try {
      Position? position;
      double? resolvedLatitude = latitude;
      double? resolvedLongitude = longitude;
      if (resolvedLatitude == null || resolvedLongitude == null) {
        try {
          position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
          );
          resolvedLatitude = position.latitude;
          resolvedLongitude = position.longitude;
        } catch (e) {
          // GPS opsional
        }
      }

      // Summary = nama tempat (locationName)
      // Notes = deskripsi (opsional)
      final resolvedLocationName = locationName ?? summary; // Summary adalah nama tempat
      final finalNotes = notes; // Notes adalah deskripsi

      // Prepare form data - patroli tanpa checkpoint
      final Map<String, dynamic> formDataMap = {
        'summary': summary, // Summary adalah nama tempat
        'type': 'patroli', // Explicitly set type
        'sentiment': 'netral',
        'focusHours': '0',
        'blockers': '[]',
        'highlights': '[]',
        'plans': '[]',
        if (resolvedLocationName.isNotEmpty) 'locationName': resolvedLocationName,
        if (finalNotes != null && finalNotes.isNotEmpty) 'notes': finalNotes,
        if (date != null) 'date': date,
        // Tidak mengirim checkpoints - patroli sederhana tanpa checkpoint
        if (resolvedLatitude != null) 'latitude': resolvedLatitude.toString(),
        if (resolvedLongitude != null) 'longitude': resolvedLongitude.toString(),
      };

      // Add multiple photos
      final formData = FormData.fromMap(formDataMap);
      if (photos.isNotEmpty) {
        for (final photo in photos) {
          formData.files.add(
            MapEntry(
              'photos', // Backend expects "photos" (plural) for multiple files
              await MultipartFile.fromFile(photo.path),
            ),
          );
        }
      }

      debugPrint('[ActivityService] Submitting patroli: $summary');
      final response = await _apiService.postFormData(
        ApiConfig.activity,
        formData,
      );

      debugPrint('[ActivityService] Patroli response: ${response.statusCode}');
      if (response.data != null) {
        debugPrint('[ActivityService] Response data: ${response.data}');
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('[ActivityService] Patroli submitted successfully');
        return {
          'success': true,
          'data': response.data['data'],
          'message': response.data['message'] ?? 'Laporan patroli berhasil disimpan',
        };
      } else {
        debugPrint('[ActivityService] Failed to submit patroli: ${response.data}');
        throw Exception(response.data['message'] ?? 'Gagal menyimpan laporan patroli');
      }
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceAll('Exception: ', ''),
      };
    }
  }

  Future<Map<String, dynamic>> getActivityById(String id) async {
    try {
      debugPrint('[ActivityService] Getting activity: $id');
      final response = await _apiService.get(ApiConfig.activityById(id));
      if (response.statusCode == 200) {
        debugPrint('[ActivityService] Activity loaded');
        return {
          'success': true,
          'data': response.data['data'],
        };
      }
      throw Exception(response.data['message'] ?? 'Gagal memuat aktivitas');
    } catch (e) {
      debugPrint('[ActivityService] Error: $e');
      return {
        'success': false,
        'message': e.toString().replaceAll('Exception: ', ''),
      };
    }
  }

  Future<Map<String, dynamic>> updateActivity({
    required String id,
    required String summary,
    String? sentiment,
    int? focusHours,
    List<String>? blockers,
    List<String>? highlights,
    List<String>? plans,
    String? notes,
    List<File> newPhotos = const [],
    List<String> existingPhotoUrls = const [],
  }) async {
    try {
      debugPrint('[ActivityService] Updating activity: $id');

      // Prepare form data - hanya summary dan foto
      final Map<String, dynamic> formDataMap = {
        'summary': summary,
      };

      // Add existing photo URLs
      for (final url in existingPhotoUrls) {
        formDataMap['existingPhotoUrls'] = url;
      }

      // Add new photos
      final formData = FormData.fromMap(formDataMap);
      if (newPhotos.isNotEmpty) {
        for (final photo in newPhotos) {
          formData.files.add(
            MapEntry(
              'photos',
              await MultipartFile.fromFile(photo.path),
            ),
          );
        }
      }

      final response = await _apiService.putFormData(
        ApiConfig.activityById(id),
        formData,
      );

      if (response.statusCode == 200) {
        debugPrint('[ActivityService] Activity updated');
        return {
          'success': true,
          'data': response.data['data'],
          'message': response.data['message'] ?? 'Aktivitas berhasil diperbarui',
        };
      } else {
        throw Exception(response.data['message'] ?? 'Gagal memperbarui aktivitas');
      }
    } catch (e) {
      debugPrint('[ActivityService] Error: $e');
      return {
        'success': false,
        'message': e.toString().replaceAll('Exception: ', ''),
      };
    }
  }

  Future<Map<String, dynamic>> deleteActivity(String id) async {
    try {
      debugPrint('[ActivityService] Deleting activity: $id');
      final response = await _apiService.delete(ApiConfig.activityById(id));
      if (response.statusCode == 200) {
        debugPrint('[ActivityService] Activity deleted');
        return {
          'success': true,
          'message': response.data['message'] ?? 'Aktivitas berhasil dihapus',
        };
      }
      throw Exception(response.data['message'] ?? 'Gagal menghapus aktivitas');
    } catch (e) {
      debugPrint('[ActivityService] Error: $e');
      return {
        'success': false,
        'message': e.toString().replaceAll('Exception: ', ''),
      };
    }
  }

}
