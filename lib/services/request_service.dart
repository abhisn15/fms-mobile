import 'dart:io';
import 'package:dio/dio.dart';
import '../config/api_config.dart';
import '../models/request_model.dart';
import 'api_service.dart';

// Explicitly import Dio types that may not be resolved
import 'package:dio/dio.dart' as dio;

class RequestService {
  final ApiService _apiService = ApiService();

  Future<RequestPayload> getRequests() async {
    try {
      final response = await _apiService.get(ApiConfig.requests);
      if (response.statusCode == 200) {
        final data = response.data['data'];
        // Handle case where data might be null or have different structure
        if (data == null) {
          return RequestPayload(requests: []);
        }
        // Ensure data has 'requests' key, or if it's directly an array
        if (data is Map<String, dynamic> && data.containsKey('requests')) {
          return RequestPayload.fromJson(data);
        } else if (data is List) {
          // If data is directly an array
          return RequestPayload(requests: data.map((e) => LeaveRequest.fromJson(e as Map<String, dynamic>)).toList());
        } else {
          return RequestPayload(requests: []);
        }
      }
      throw Exception('Gagal memuat data request');
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createRequest({
    required String type,
    required String reason,
    required String startDate,
    required String endDate,
    List<File> photos = const [],
  }) async {
    try {
      if (photos.isNotEmpty) {
        // Use FormData when photos are provided
        final formData = dio.FormData.fromMap({
          'type': type,
          'reason': reason,
          'startDate': startDate,
          'endDate': endDate,
        });

        // Add photos to form data
        for (final photo in photos) {
          formData.files.add(
            MapEntry(
              'photos', // Backend expects "photos" for multiple files
              await dio.MultipartFile.fromFile(photo.path),
            ),
          );
        }

        final response = await _apiService.postFormData(ApiConfig.requests, formData);

        if (response.statusCode == 200 || response.statusCode == 201) {
          return {
            'success': true,
            'data': response.data['data'],
            'message': response.data['message'] ?? 'Request berhasil dikirim',
          };
        } else {
          throw Exception(response.data['message'] ?? 'Gagal mengirim request');
        }
      } else {
        // Use regular JSON when no photos
        final response = await _apiService.post(
          ApiConfig.requests,
          data: {
            'type': type,
            'reason': reason,
            'startDate': startDate,
            'endDate': endDate,
          },
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          return {
            'success': true,
            'data': response.data['data'],
            'message': response.data['message'] ?? 'Request berhasil dikirim',
          };
        } else {
          throw Exception(response.data['message'] ?? 'Gagal mengirim request');
        }
      }
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceAll('Exception: ', ''),
      };
    }
  }
}

