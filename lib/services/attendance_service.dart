import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../config/api_config.dart';
import '../models/attendance_model.dart';
import '../models/shift_model.dart';
import '../utils/error_handler.dart';
import 'api_service.dart';

class AttendanceService {
  final ApiService _apiService = ApiService();

  Future<AttendancePayload> getAttendance({DateTime? startDate, DateTime? endDate}) async {
    debugPrint('[AttendanceService] Loading attendance data...');
    try {
      String url = ApiConfig.attendance;
      if (startDate != null && endDate != null) {
        final startDateStr = startDate.toIso8601String().split('T')[0];
        final endDateStr = endDate.toIso8601String().split('T')[0];
        url = '${ApiConfig.attendance}?startDate=$startDateStr&endDate=$endDateStr';
        debugPrint('[AttendanceService] Using date range: $startDateStr to $endDateStr');
      }
      
      final response = await _apiService.get(url);
      if (response.statusCode == 200) {
        debugPrint('[AttendanceService] ✓ Attendance data loaded successfully');
        final payload = AttendancePayload.fromJson(response.data['data']);
        debugPrint('[AttendanceService] Today: ${payload.today?.status ?? 'null'}, History count: ${payload.recent.length}');
        // Log semua status untuk debugging
        for (var record in payload.recent) {
          debugPrint('[AttendanceService] - ${record.date}: ${record.status} (${record.checkIn ?? '-'} - ${record.checkOut ?? '-'})');
        }
        return payload;
      }
      // Handle non-200 responses
      if (response.statusCode != null && response.statusCode! >= 400) {
        final errorMessage = response.data?['message'] ?? 
                           response.data?['error'] ?? 
                           'Gagal memuat data attendance';
        debugPrint('[AttendanceService] ✗ Error ${response.statusCode}: $errorMessage');
        throw DioException(
          requestOptions: RequestOptions(path: ApiConfig.attendance),
          response: response,
          type: DioExceptionType.badResponse,
          error: errorMessage,
        );
      }
      throw Exception('Gagal memuat data attendance');
    } catch (e) {
      debugPrint('[AttendanceService] ✗ Exception: $e');
      rethrow;
    }
  }

  Future<ShiftSchedulePayload> getShiftSchedule() async {
    debugPrint('[AttendanceService] Loading shift schedule...');
    try {
      final response = await _apiService.get(ApiConfig.shifts);
      if (response.statusCode == 200) {
        debugPrint('[AttendanceService] ✓ Shift schedule loaded successfully');
        return ShiftSchedulePayload.fromJson(response.data['data']);
      }
      // Handle non-200 responses
      if (response.statusCode != null && response.statusCode! >= 400) {
        final errorMessage = response.data?['message'] ?? 
                           response.data?['error'] ?? 
                           'Gagal memuat shift schedule';
        debugPrint('[AttendanceService] ✗ Error ${response.statusCode}: $errorMessage');
        throw DioException(
          requestOptions: RequestOptions(path: ApiConfig.shifts),
          response: response,
          type: DioExceptionType.badResponse,
          error: errorMessage,
        );
      }
      throw Exception('Gagal memuat shift schedule');
    } catch (e) {
      debugPrint('[AttendanceService] ✗ Exception: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> checkIn({
    required File photo,
    required String shiftId,
    double? latitude,
    double? longitude,
  }) async {
    debugPrint('[AttendanceService] Starting check-in...');
    debugPrint('[AttendanceService] Shift ID: $shiftId');
    debugPrint('[AttendanceService] Photo path: ${photo.path}');
    try {
      // Ambil GPS jika belum ada
      Position? position;
      if (latitude == null || longitude == null) {
        try {
          debugPrint('[AttendanceService] Checking location permission...');
          // Check permission status
          LocationPermission permission = await Geolocator.checkPermission();
          
          if (permission == LocationPermission.denied) {
            debugPrint('[AttendanceService] Permission denied, requesting...');
            permission = await Geolocator.requestPermission();
            
            if (permission == LocationPermission.denied) {
              debugPrint('[AttendanceService] Permission denied by user');
              // GPS opsional, lanjutkan tanpa koordinat
            } else if (permission == LocationPermission.deniedForever) {
              debugPrint('[AttendanceService] Permission denied forever, skipping GPS');
              // GPS opsional, lanjutkan tanpa koordinat
            }
          }
          
          if (permission == LocationPermission.whileInUse || 
              permission == LocationPermission.always) {
            debugPrint('[AttendanceService] Permission granted, getting GPS location...');
            // Check if location services are enabled
            bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
            if (!serviceEnabled) {
              debugPrint('[AttendanceService] Location services disabled');
              // GPS opsional, lanjutkan tanpa koordinat
            } else {
              try {
                position = await Geolocator.getCurrentPosition(
                  desiredAccuracy: LocationAccuracy.high,
                  timeLimit: const Duration(seconds: 15), // Increased timeout
                );
                latitude = position.latitude;
                longitude = position.longitude;
                debugPrint('[AttendanceService] ✓ GPS obtained: $latitude, $longitude');
              } catch (timeoutError) {
                if (timeoutError.toString().contains('TimeoutException')) {
                  debugPrint('[AttendanceService] ⚠ GPS timeout (15s) - continuing without GPS (optional)');
                } else {
                  debugPrint('[AttendanceService] ⚠ GPS error: $timeoutError - continuing without GPS (optional)');
                }
                // GPS opsional, lanjutkan tanpa koordinat
              }
            }
          } else {
            debugPrint('[AttendanceService] Permission not granted, skipping GPS');
          }
        } catch (e) {
          debugPrint('[AttendanceService] ⚠ GPS error (optional): $e - continuing without GPS');
          // GPS opsional, lanjutkan tanpa koordinat
        }
      } else {
        debugPrint('[AttendanceService] Using provided GPS: $latitude, $longitude');
      }

      final formData = FormData.fromMap({
        'photo': await MultipartFile.fromFile(photo.path),
        'shiftId': shiftId,
        if (latitude != null) 'latitude': latitude.toString(),
        if (longitude != null) 'longitude': longitude.toString(),
      });

      debugPrint('[AttendanceService] Sending check-in request...');
      final response = await _apiService.postFormData(
        ApiConfig.checkIn,
        formData,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('[AttendanceService] ✓ Check-in successful');
        return {
          'success': true,
          'data': response.data['data'],
          'message': response.data['message'] ?? 'Check-in berhasil',
        };
      } else {
        // Handle error response
        final errorMessage = response.data?['message'] ?? 
                           response.data?['error'] ?? 
                           'Check-in gagal';
        debugPrint('[AttendanceService] ✗ Check-in failed: $errorMessage (Status: ${response.statusCode})');
        throw DioException(
          requestOptions: RequestOptions(path: ApiConfig.checkIn),
          response: response,
          type: DioExceptionType.badResponse,
          error: errorMessage,
        );
      }
    } catch (e) {
      final errorMsg = ErrorHandler.getErrorMessage(e);
      debugPrint('[AttendanceService] ✗ Check-in exception: $e');
      debugPrint('[AttendanceService] User-friendly error: $errorMsg');
      return {
        'success': false,
        'message': errorMsg,
      };
    }
  }

  Future<Map<String, dynamic>> checkOut({
    required File photo,
    double? latitude,
    double? longitude,
  }) async {
    debugPrint('[AttendanceService] Starting check-out...');
    debugPrint('[AttendanceService] Photo path: ${photo.path}');
    try {
      // Ambil GPS jika belum ada
      Position? position;
      if (latitude == null || longitude == null) {
        try {
          debugPrint('[AttendanceService] Checking location permission...');
          // Check permission status
          LocationPermission permission = await Geolocator.checkPermission();
          
          if (permission == LocationPermission.denied) {
            debugPrint('[AttendanceService] Permission denied, requesting...');
            permission = await Geolocator.requestPermission();
            
            if (permission == LocationPermission.denied) {
              debugPrint('[AttendanceService] Permission denied by user');
              // GPS opsional, lanjutkan tanpa koordinat
            } else if (permission == LocationPermission.deniedForever) {
              debugPrint('[AttendanceService] Permission denied forever, skipping GPS');
              // GPS opsional, lanjutkan tanpa koordinat
            }
          }
          
          if (permission == LocationPermission.whileInUse || 
              permission == LocationPermission.always) {
            debugPrint('[AttendanceService] Permission granted, getting GPS location...');
            // Check if location services are enabled
            bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
            if (!serviceEnabled) {
              debugPrint('[AttendanceService] Location services disabled');
              // GPS opsional, lanjutkan tanpa koordinat
            } else {
              try {
                position = await Geolocator.getCurrentPosition(
                  desiredAccuracy: LocationAccuracy.high,
                  timeLimit: const Duration(seconds: 15), // Increased timeout
                );
                latitude = position.latitude;
                longitude = position.longitude;
                debugPrint('[AttendanceService] ✓ GPS obtained: $latitude, $longitude');
              } catch (timeoutError) {
                if (timeoutError.toString().contains('TimeoutException')) {
                  debugPrint('[AttendanceService] ⚠ GPS timeout (15s) - continuing without GPS (optional)');
                } else {
                  debugPrint('[AttendanceService] ⚠ GPS error: $timeoutError - continuing without GPS (optional)');
                }
                // GPS opsional, lanjutkan tanpa koordinat
              }
            }
          } else {
            debugPrint('[AttendanceService] Permission not granted, skipping GPS');
          }
        } catch (e) {
          debugPrint('[AttendanceService] ⚠ GPS error (optional): $e - continuing without GPS');
          // GPS opsional, lanjutkan tanpa koordinat
        }
      } else {
        debugPrint('[AttendanceService] Using provided GPS: $latitude, $longitude');
      }

      final formData = FormData.fromMap({
        'photo': await MultipartFile.fromFile(photo.path),
        if (latitude != null) 'latitude': latitude.toString(),
        if (longitude != null) 'longitude': longitude.toString(),
      });

      debugPrint('[AttendanceService] Sending check-out request...');
      final response = await _apiService.postFormData(
        ApiConfig.checkOut,
        formData,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('[AttendanceService] ✓ Check-out successful');
        return {
          'success': true,
          'data': response.data['data'],
          'message': response.data['message'] ?? 'Check-out berhasil',
        };
      } else {
        // Handle error response
        final errorMessage = response.data?['message'] ?? 
                           response.data?['error'] ?? 
                           'Check-out gagal';
        debugPrint('[AttendanceService] ✗ Check-out failed: $errorMessage (Status: ${response.statusCode})');
        throw DioException(
          requestOptions: RequestOptions(path: ApiConfig.checkOut),
          response: response,
          type: DioExceptionType.badResponse,
          error: errorMessage,
        );
      }
    } catch (e) {
      final errorMsg = ErrorHandler.getErrorMessage(e);
      debugPrint('[AttendanceService] ✗ Check-out exception: $e');
      debugPrint('[AttendanceService] User-friendly error: $errorMsg');
      return {
        'success': false,
        'message': errorMsg,
      };
    }
  }
}

