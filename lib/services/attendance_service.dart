import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../config/api_config.dart';
import '../models/attendance_model.dart';
import '../models/user_model.dart' show Site;
import '../models/shift_model.dart';
import '../utils/error_handler.dart';
import 'api_service.dart';

class AttendanceService {
  final ApiService _apiService = ApiService();

  void _validateGeofence({
    required Site? site,
    required double? latitude,
    required double? longitude,
    required String actionLabel,
  }) {
    final siteLat = site?.latitude;
    final siteLng = site?.longitude;
    final maxRadiusMeters = site?.maxRadiusMeters;
    if (siteLat == null || siteLng == null || maxRadiusMeters == null) {
      return;
    }
    final placementName = site?.name?.trim();
    final locationLabel = (placementName != null && placementName.isNotEmpty)
        ? placementName
        : 'lokasi penempatan';
    final requirementLabel = 'dalam radius ${maxRadiusMeters}m dari $locationLabel';
    if (latitude == null || longitude == null) {
      throw Exception(
        'GPS wajib aktif untuk $actionLabel. Pastikan berada $requirementLabel.',
      );
    }
    final distance = Geolocator.distanceBetween(siteLat, siteLng, latitude, longitude);
    if (distance > maxRadiusMeters.toDouble()) {
      throw Exception(
        'Lokasi di luar radius (${distance.round()}m > ${maxRadiusMeters}m) dari $locationLabel. '
        'Pindah ke area penempatan untuk $actionLabel.',
      );
    }
  }

  Future<Map<String, double>> getRequiredLocation({required String actionLabel}) async {
    debugPrint('[AttendanceService] Checking location permission...');
    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw Exception('Izin lokasi ditolak. Aktifkan GPS untuk $actionLabel.');
    }

    if (permission == LocationPermission.deniedForever) {
      await Geolocator.openAppSettings();
      throw Exception('Izin lokasi ditolak permanen. Aktifkan dari pengaturan untuk $actionLabel.');
    }

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      throw Exception('GPS belum aktif. Aktifkan lokasi untuk $actionLabel.');
    }

    debugPrint('[AttendanceService] Getting GPS location...');
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );
      debugPrint('[AttendanceService] ✓ GPS obtained: ${position.latitude}, ${position.longitude}');
      return {
        'latitude': position.latitude,
        'longitude': position.longitude,
      };
    } on TimeoutException {
      throw Exception('Gagal mendapatkan lokasi GPS. Pastikan sinyal GPS bagus lalu coba lagi.');
    } catch (e) {
      throw Exception('Gagal mendapatkan lokasi GPS. ${e.toString()}');
    }
  }

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
    String? shiftId, // Opsional - jika tidak ada, gunakan shift yang di-assign atau absen tanpa shift
    double? latitude,
    double? longitude,
    Site? site,
  }) async {
    debugPrint('[AttendanceService] Starting check-in...');
    debugPrint('[AttendanceService] Shift ID: ${shiftId ?? "null (no shift)"}');
    debugPrint('[AttendanceService] Photo path: ${photo.path}');
    try {
      if (latitude == null || longitude == null) {
        final location = await getRequiredLocation(actionLabel: 'check-in');
        latitude = location['latitude'];
        longitude = location['longitude'];
      } else {
        debugPrint('[AttendanceService] Using provided GPS: $latitude, $longitude');
      }

      _validateGeofence(
        site: site,
        latitude: latitude,
        longitude: longitude,
        actionLabel: 'check-in',
      );

      // Validasi file sebelum upload untuk mencegah OOM di device low-end
      try {
        final fileStat = await photo.stat();
        final fileSizeMB = fileStat.size / (1024 * 1024);
        debugPrint('[AttendanceService] Photo size: ${fileSizeMB.toStringAsFixed(2)} MB');
        
        // Jika file terlalu besar (>10MB), bisa menyebabkan OOM di device low-end
        if (fileSizeMB > 10) {
          throw Exception('Foto terlalu besar (${fileSizeMB.toStringAsFixed(2)} MB). Maksimal 10 MB.');
        }
      } catch (e) {
        if (e.toString().contains('terlalu besar')) {
          rethrow;
        }
        debugPrint('[AttendanceService] ⚠ Could not check file size: $e');
        // Continue anyway if we can't check size
      }

      // Buat MultipartFile dengan error handling untuk mencegah OOM
      MultipartFile? photoFile;
      try {
        photoFile = await MultipartFile.fromFile(
          photo.path,
        ).timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw Exception('Timeout saat membaca file foto. File mungkin terlalu besar.');
          },
        );
      } catch (e) {
        if (e.toString().contains('OutOfMemory') || 
            e.toString().contains('out of memory') ||
            e.toString().contains('Memory')) {
          throw Exception('Memori tidak cukup untuk memproses foto. Coba ambil foto dengan resolusi lebih kecil.');
        }
        rethrow;
      }

      final formData = FormData.fromMap({
        'photo': photoFile,
        if (shiftId != null) 'shiftId': shiftId, // Opsional - hanya kirim jika ada
        if (latitude != null) 'latitude': latitude.toString(),
        if (longitude != null) 'longitude': longitude.toString(),
      });

      debugPrint('[AttendanceService] Sending check-in request...');
      final response = await _apiService.postFormData(
        ApiConfig.checkIn,
        formData,
      ).timeout(
        const Duration(seconds: 60), // Timeout 60 detik untuk upload
        onTimeout: () {
          throw Exception('Upload timeout. Koneksi mungkin lambat atau file terlalu besar.');
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('[AttendanceService] ✓ Check-in successful');
        // Safely parse response data
        final responseData = response.data;
        final data = (responseData is Map && responseData.containsKey('data')) 
            ? responseData['data'] 
            : responseData;
        final message = (responseData is Map && responseData.containsKey('message'))
            ? (responseData['message'] as String?)
            : 'Check-in berhasil';
        
        return {
          'success': true,
          'data': data,
          'message': message ?? 'Check-in berhasil',
        };
      } else {
        // Handle error response
        final responseData = response.data;
        final errorMessage = (responseData is Map)
            ? (responseData['message'] ?? responseData['error'] ?? 'Check-in gagal')
            : 'Check-in gagal';
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
    Site? site,
  }) async {
    debugPrint('[AttendanceService] Starting check-out...');
    debugPrint('[AttendanceService] Photo path: ${photo.path}');
    try {
      if (latitude == null || longitude == null) {
        final location = await getRequiredLocation(actionLabel: 'check-out');
        latitude = location['latitude'];
        longitude = location['longitude'];
      } else {
        debugPrint('[AttendanceService] Using provided GPS: $latitude, $longitude');
      }

      _validateGeofence(
        site: site,
        latitude: latitude,
        longitude: longitude,
        actionLabel: 'check-out',
      );

      // Validasi file sebelum upload untuk mencegah OOM di device low-end
      try {
        final fileStat = await photo.stat();
        final fileSizeMB = fileStat.size / (1024 * 1024);
        debugPrint('[AttendanceService] Photo size: ${fileSizeMB.toStringAsFixed(2)} MB');
        
        // Jika file terlalu besar (>10MB), bisa menyebabkan OOM di device low-end
        if (fileSizeMB > 10) {
          throw Exception('Foto terlalu besar (${fileSizeMB.toStringAsFixed(2)} MB). Maksimal 10 MB.');
        }
      } catch (e) {
        if (e.toString().contains('terlalu besar')) {
          rethrow;
        }
        debugPrint('[AttendanceService] ⚠ Could not check file size: $e');
        // Continue anyway if we can't check size
      }

      // Buat MultipartFile dengan error handling untuk mencegah OOM
      MultipartFile? photoFile;
      try {
        photoFile = await MultipartFile.fromFile(
          photo.path,
        ).timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw Exception('Timeout saat membaca file foto. File mungkin terlalu besar.');
          },
        );
      } catch (e) {
        if (e.toString().contains('OutOfMemory') || 
            e.toString().contains('out of memory') ||
            e.toString().contains('Memory')) {
          throw Exception('Memori tidak cukup untuk memproses foto. Coba ambil foto dengan resolusi lebih kecil.');
        }
        rethrow;
      }

      final formData = FormData.fromMap({
        'photo': photoFile,
        if (latitude != null) 'latitude': latitude.toString(),
        if (longitude != null) 'longitude': longitude.toString(),
      });

      debugPrint('[AttendanceService] Sending check-out request...');
      final response = await _apiService.postFormData(
        ApiConfig.checkOut,
        formData,
      ).timeout(
        const Duration(seconds: 60), // Timeout 60 detik untuk upload
        onTimeout: () {
          throw Exception('Upload timeout. Koneksi mungkin lambat atau file terlalu besar.');
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('[AttendanceService] ✓ Check-out successful');
        // Safely parse response data
        final responseData = response.data;
        final data = (responseData is Map && responseData.containsKey('data')) 
            ? responseData['data'] 
            : responseData;
        final message = (responseData is Map && responseData.containsKey('message'))
            ? (responseData['message'] as String?)
            : 'Check-out berhasil';
        
        return {
          'success': true,
          'data': data,
          'message': message ?? 'Check-out berhasil',
        };
      } else {
        // Handle error response
        final responseData = response.data;
        final errorMessage = (responseData is Map)
            ? (responseData['message'] ?? responseData['error'] ?? 'Check-out gagal')
            : 'Check-out gagal';
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

