import 'dart:io';
import 'dart:convert';
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
          debugPrint('[ActivityService] ✗ Data is null');
          throw Exception('Data aktivitas tidak ditemukan');
        }
        debugPrint('[ActivityService] ✓ Data received: ${data['entries']?.length ?? 0} entries');
        final payload = ActivityPayload.fromJson(data);
        debugPrint('[ActivityService] ✓ Parsed: today=${payload.today != null}, recent=${payload.recent.length}');
        return payload;
      }
      debugPrint('[ActivityService] ✗ Status code: ${response.statusCode}');
      throw Exception('Gagal memuat data aktivitas');
    } catch (e) {
      debugPrint('[ActivityService] ✗ Error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> submitDailyActivity({
    required String summary,
    required String sentiment,
    required int focusHours,
    required List<String> blockers,
    required List<String> highlights,
    required List<String> plans,
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

      // Prepare form data
      final Map<String, dynamic> formDataMap = {
        'summary': summary,
        'sentiment': sentiment,
        'focusHours': focusHours.toString(),
        'highlights': jsonEncode(highlights),
        'blockers': jsonEncode(blockers),
        'plans': jsonEncode(plans),
        if (notes != null && notes.isNotEmpty) 'notes': notes,
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
    required List<SecurityCheckpoint> checkpoints,
    String? notes,
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

      // Format checkpoints sesuai dengan backend (JSON string)
      // Backend mengharapkan format: { id, name, completed, timestamp?, coordinates?: {lat, lng}, photoUrl?, photoReason? }
      final checkpointsJson = checkpoints.map((cp) {
        final checkpointData = <String, dynamic>{
          'id': cp.id,
          'name': cp.name,
          'completed': cp.completed,
        };
        
        if (cp.completed) {
          checkpointData['timestamp'] = DateTime.now().toIso8601String();
        }
        
        if (cp.latitude != null && cp.longitude != null) {
          checkpointData['coordinates'] = {
            'lat': cp.latitude,
            'lng': cp.longitude,
          };
        }
        
        if (cp.photoUrl != null) {
          checkpointData['photoUrl'] = cp.photoUrl;
        }
        
        if (cp.reason != null && cp.reason!.isNotEmpty) {
          checkpointData['photoReason'] = cp.reason;
        }
        
        return checkpointData;
      }).toList();

      final formData = FormData.fromMap({
        'summary': summary,
        'sentiment': 'netral',
        'focusHours': '0',
        'blockers': '[]',
        'highlights': '[]',
        'plans': '[]',
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        'checkpoints': jsonEncode(checkpointsJson), // Kirim sebagai JSON string
        if (position != null) 'latitude': position.latitude.toString(),
        if (position != null) 'longitude': position.longitude.toString(),
      });

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
        debugPrint('[ActivityService] ✓ Activity loaded');
        return {
          'success': true,
          'data': response.data['data'],
        };
      }
      throw Exception(response.data['message'] ?? 'Gagal memuat aktivitas');
    } catch (e) {
      debugPrint('[ActivityService] ✗ Error: $e');
      return {
        'success': false,
        'message': e.toString().replaceAll('Exception: ', ''),
      };
    }
  }

  Future<Map<String, dynamic>> updateActivity({
    required String id,
    required String summary,
    required String sentiment,
    required int focusHours,
    required List<String> blockers,
    required List<String> highlights,
    required List<String> plans,
    String? notes,
    List<File> newPhotos = const [],
    List<String> existingPhotoUrls = const [],
  }) async {
    try {
      debugPrint('[ActivityService] Updating activity: $id');
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
      } catch (e) {
        // GPS opsional
      }

      // Prepare form data
      final Map<String, dynamic> formDataMap = {
        'summary': summary,
        'sentiment': sentiment,
        'focusHours': focusHours.toString(),
        'highlights': jsonEncode(highlights),
        'blockers': jsonEncode(blockers),
        'plans': jsonEncode(plans),
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        if (position != null) 'latitude': position.latitude.toString(),
        if (position != null) 'longitude': position.longitude.toString(),
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
        debugPrint('[ActivityService] ✓ Activity updated');
        return {
          'success': true,
          'data': response.data['data'],
          'message': response.data['message'] ?? 'Aktivitas berhasil diperbarui',
        };
      } else {
        throw Exception(response.data['message'] ?? 'Gagal memperbarui aktivitas');
      }
    } catch (e) {
      debugPrint('[ActivityService] ✗ Error: $e');
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
        debugPrint('[ActivityService] ✓ Activity deleted');
        return {
          'success': true,
          'message': response.data['message'] ?? 'Aktivitas berhasil dihapus',
        };
      }
      throw Exception(response.data['message'] ?? 'Gagal menghapus aktivitas');
    } catch (e) {
      debugPrint('[ActivityService] ✗ Error: $e');
      return {
        'success': false,
        'message': e.toString().replaceAll('Exception: ', ''),
      };
    }
  }

  Future<Map<String, dynamic>> uploadCheckpointPhoto({
    required File photo,
    required String checkpointId,
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

      final formData = FormData.fromMap({
        'photo': await MultipartFile.fromFile(photo.path),
        'checkpointId': checkpointId,
        if (position != null) 'latitude': position.latitude.toString(),
        if (position != null) 'longitude': position.longitude.toString(),
      });

      final response = await _apiService.postFormData(
        ApiConfig.checkpointPhoto,
        formData,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'data': response.data['data'],
          'message': response.data['message'] ?? 'Foto checkpoint berhasil diunggah',
        };
      } else {
        throw Exception(response.data['message'] ?? 'Gagal mengunggah foto checkpoint');
      }
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceAll('Exception: ', ''),
      };
    }
  }
}

