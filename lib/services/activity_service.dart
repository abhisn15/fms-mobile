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
      final response = await _apiService.get(ApiConfig.activity);
      if (response.statusCode == 200) {
        // Backend returns { data: { entries: [...], timeline: [...] } }
        final data = response.data['data'];
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
          throw Exception('Format data aktivitas tidak valid');
        }
        final entriesCount = payloadSource['entries'] is List
            ? (payloadSource['entries'] as List).length
            : 0;
        debugPrint('[ActivityService] Data received: $entriesCount entries');
        final payload = ActivityPayload.fromJson(payloadSource);
        debugPrint('[ActivityService] Parsed: today=${payload.today != null}, recent=${payload.recent.length}');
        return payload;
      }
      debugPrint('[ActivityService] Status code: ${response.statusCode}');
      throw Exception('Gagal memuat data aktivitas');
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
  }) async {
    try {
      // Prepare form data - hanya summary dan foto
      final Map<String, dynamic> formDataMap = {
        'summary': summary,
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

      final response = await _apiService.postFormData(
        ApiConfig.activity,
        formData,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'data': response.data['data'],
          'message': response.data['message'] ?? 'Aktivitas berhasil disimpan',
        };
      } else {
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
  }) async {
    try {
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
      } catch (e) {
        // GPS opsional
      }

      // Summary = nama tempat (locationName)
      // Notes = deskripsi (opsional)
      final locationName = summary; // Summary adalah nama tempat
      final finalNotes = notes; // Notes adalah deskripsi

      // Prepare form data - patroli tanpa checkpoint
      final Map<String, dynamic> formDataMap = {
        'summary': summary, // Summary adalah nama tempat
        'sentiment': 'netral',
        'focusHours': '0',
        'blockers': '[]',
        'highlights': '[]',
        'plans': '[]',
        if (locationName.isNotEmpty) 'locationName': locationName,
        if (finalNotes != null && finalNotes.isNotEmpty) 'notes': finalNotes,
        // Tidak mengirim checkpoints - patroli sederhana tanpa checkpoint
        if (position != null) 'latitude': position.latitude.toString(),
        if (position != null) 'longitude': position.longitude.toString(),
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

      final response = await _apiService.postFormData(
        ApiConfig.activity,
        formData,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'data': response.data['data'],
          'message': response.data['message'] ?? 'Laporan patroli berhasil disimpan',
        };
      } else {
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
