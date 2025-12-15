import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../config/api_config.dart';
import 'api_service.dart';
import '../utils/error_handler.dart';

class ProfileService {
  final ApiService _apiService = ApiService();

  /// Update profile user
  Future<Map<String, dynamic>> updateProfile({
    required String name,
    required String email,
    required String title,
    String? team,
    String? avatarColor,
    File? photo,
    String? newPassword, // Password baru (opsional)
  }) async {
    debugPrint('[ProfileService] Updating profile...');
    try {
      Response response;
      
      if (photo != null) {
        // Jika ada foto, gunakan FormData dengan PUT
        final formDataMap = <String, dynamic>{
          'name': name,
          'email': email,
          'title': title,
          'team': team ?? '',
          'avatarColor': avatarColor ?? '#1d4ed8',
          'photo': await MultipartFile.fromFile(photo.path),
        };
        
        // Tambahkan password jika diisi
        if (newPassword != null && newPassword.trim().isNotEmpty) {
          formDataMap['newPassword'] = newPassword.trim();
        }
        
        final formData = FormData.fromMap(formDataMap);
        
        response = await _apiService.putFormData(
          ApiConfig.profile,
          formData,
        );
      } else {
        // Jika tidak ada foto, gunakan JSON dengan PUT
        final data = <String, dynamic>{
          'name': name,
          'email': email,
          'title': title,
          'team': team,
          'avatarColor': avatarColor ?? '#1d4ed8',
        };
        
        // Tambahkan password jika diisi
        if (newPassword != null && newPassword.trim().isNotEmpty) {
          data['newPassword'] = newPassword.trim();
        }
        
        response = await _apiService.put(
          ApiConfig.profile,
          data: data,
        );
      }

      if (response.statusCode == 200) {
        debugPrint('[ProfileService] ✓ Profile updated successfully');
        return {
          'success': true,
          'data': response.data['data'],
          'message': response.data['message'] ?? 'Profile berhasil diperbarui',
        };
      } else {
        final errorMessage = response.data['message'] ?? 'Gagal memperbarui profile';
        debugPrint('[ProfileService] ✗ Error ${response.statusCode}: $errorMessage');
        throw DioException(
          requestOptions: RequestOptions(path: ApiConfig.profile),
          response: response,
          type: DioExceptionType.badResponse,
          error: errorMessage,
        );
      }
    } catch (e) {
      final errorMsg = ErrorHandler.getErrorMessage(e);
      debugPrint('[ProfileService] ✗ Exception: $e');
      debugPrint('[ProfileService] User-friendly error: $errorMsg');
      return {
        'success': false,
        'message': errorMsg,
      };
    }
  }

  /// Set password baru untuk user (tanpa perlu password lama)
  Future<Map<String, dynamic>> setPassword(String newPassword) async {
    debugPrint('[ProfileService] Setting new password...');
    try {
      final response = await _apiService.post(
        ApiConfig.setPassword,
        data: {
          'newPassword': newPassword,
        },
      );

      if (response.statusCode == 200) {
        debugPrint('[ProfileService] ✓ Password set successfully');
        return {
          'success': true,
          'message': response.data['message'] ?? 'Password berhasil dibuat',
        };
      } else {
        final errorMessage = response.data['message'] ?? 'Gagal membuat password';
        debugPrint('[ProfileService] ✗ Error ${response.statusCode}: $errorMessage');
        throw DioException(
          requestOptions: RequestOptions(path: ApiConfig.setPassword),
          response: response,
          type: DioExceptionType.badResponse,
          error: errorMessage,
        );
      }
    } catch (e) {
      final errorMsg = ErrorHandler.getErrorMessage(e);
      debugPrint('[ProfileService] ✗ Exception: $e');
      debugPrint('[ProfileService] User-friendly error: $errorMsg');
      return {
        'success': false,
        'message': errorMsg,
      };
    }
  }
}
