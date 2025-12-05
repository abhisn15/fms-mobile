import 'dart:io';
import 'package:dio/dio.dart';
import '../config/api_config.dart';
import '../models/user_model.dart';
import 'api_service.dart';

class ProfileService {
  final ApiService _apiService = ApiService();

  Future<User> getProfile() async {
    try {
      final response = await _apiService.get(ApiConfig.profile);
      if (response.statusCode == 200) {
        return User.fromJson(response.data['data']);
      }
      throw Exception('Gagal memuat profil');
    } catch (e) {
      rethrow;
    }
  }

  /// Update profile photo only (legacy method, kept for backward compatibility)
  Future<Map<String, dynamic>> updateProfilePhoto(File photo) async {
    try {
      final formData = FormData.fromMap({
        'photo': await MultipartFile.fromFile(photo.path),
      });

      final response = await _apiService.putFormData(
        ApiConfig.profile,
        formData,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'data': response.data['data'],
          'message': response.data['message'] ?? 'Foto profil berhasil diupdate',
        };
      } else {
        throw Exception(response.data['message'] ?? 'Gagal mengupdate foto profil');
      }
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceAll('Exception: ', ''),
      };
    }
  }

  /// Update full profile with all fields
  Future<Map<String, dynamic>> updateProfile({
    required String name,
    required String email,
    required String title,
    String? team,
    String? avatarColor,
    File? photo,
  }) async {
    try {
      Map<String, dynamic> result;

      // If photo is provided, use FormData
      if (photo != null) {
        final formData = FormData.fromMap({
          'name': name,
          'email': email,
          'title': title,
          'team': team ?? '',
          'avatarColor': avatarColor ?? '#1d4ed8',
          'photo': await MultipartFile.fromFile(photo.path),
        });

        final response = await _apiService.putFormData(
          ApiConfig.profile,
          formData,
        );

        if (response.statusCode == 200) {
          result = {
            'success': true,
            'data': response.data['data'],
            'message': response.data['message'] ?? 'Profile berhasil diperbarui',
          };
        } else {
          throw Exception(response.data['message'] ?? 'Gagal memperbarui profile');
        }
      } else {
        // No photo, use JSON
        final response = await _apiService.put(
          ApiConfig.profile,
          data: {
            'name': name,
            'email': email,
            'title': title,
            'team': team,
            'avatarColor': avatarColor ?? '#1d4ed8',
          },
        );

        if (response.statusCode == 200) {
          result = {
            'success': true,
            'data': response.data['data'],
            'message': response.data['message'] ?? 'Profile berhasil diperbarui',
          };
        } else {
          throw Exception(response.data['message'] ?? 'Gagal memperbarui profile');
        }
      }

      return result;
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceAll('Exception: ', ''),
      };
    }
  }
}

