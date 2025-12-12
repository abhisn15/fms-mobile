import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import '../config/api_config.dart';
import '../models/user_model.dart';
import 'api_service.dart';

class AuthService {
  final ApiService _apiService = ApiService();
  static const String _userKey = 'user_data';
  static const String _isLoggedInKey = 'is_logged_in';

  /// Login dengan email atau NIK KTP
  /// [email] bisa berupa email atau NIK KTP
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await _apiService.post(
        ApiConfig.login,
        data: {
          'email': email, // Bisa berupa email atau NIK KTP
          'password': password,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data['data'];
        final user = User.fromJson(data['user']);

        // Validasi: hanya karyawan yang bisa login
        if (user.role != 'karyawan') {
          throw Exception('Login hanya untuk karyawan');
        }

        // Simpan user data
        await _saveUser(user);
        await _setLoggedIn(true);

        return {
          'success': true,
          'user': user,
          'message': response.data['message'] ?? 'Login berhasil',
        };
      } else {
        throw Exception(response.data['message'] ?? 'Login gagal');
      }
    } catch (e) {
      String errorMessage = 'Login gagal';
      if (e is DioException) {
        if (e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.sendTimeout) {
          errorMessage = 'Koneksi timeout. Pastikan backend server berjalan dan dapat diakses.';
        } else if (e.type == DioExceptionType.connectionError) {
          errorMessage = 'Tidak dapat terhubung ke server. Pastikan backend server berjalan.';
        } else {
          errorMessage = e.message ?? 'Login gagal';
        }
      } else {
        errorMessage = e.toString().replaceAll('Exception: ', '');
      }
      return {
        'success': false,
        'message': errorMessage,
      };
    }
  }

  Future<User?> getCurrentUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString(_userKey);
      if (userJson == null) return null;

      // Verifikasi session dengan backend
      final response = await _apiService.get(ApiConfig.session);
      if (response.statusCode == 200 && response.data['data'] != null) {
        final userData = response.data['data'];
        debugPrint('[AuthService] User data from session: name="${userData['name']}", email="${userData['email']}"');
        final user = User.fromJson(userData);
        debugPrint('[AuthService] Parsed user: name="${user.name}", email="${user.email}"');
        return user;
      }
      // Session expired atau tidak valid
      if (response.statusCode == 401 || response.statusCode == 403) {
        // Clear local data
        await logout();
      }
      return null;
    } catch (e) {
      // Jika error karena session expired, clear local data
      if (e is DioException && (e.response?.statusCode == 401 || e.response?.statusCode == 403)) {
        await logout();
      }
      return null;
    }
  }

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isLoggedInKey) ?? false;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
    await prefs.remove(_isLoggedInKey);
    await prefs.remove('cookies');
  }

  Future<void> _saveUser(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, user.toJson().toString());
  }

  Future<void> _setLoggedIn(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isLoggedInKey, value);
  }
}

