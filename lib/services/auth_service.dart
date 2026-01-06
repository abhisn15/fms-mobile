import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import '../config/api_config.dart';
import '../models/user_model.dart';
import 'api_service.dart';

class AuthService {
  final ApiService _apiService = ApiService();
  static const String _userKey = 'user_data';
  static const String _isLoggedInKey = 'is_logged_in';
  static const String _legacyUserKey = 'user_data_legacy';

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
          // ✅ Ambil error message dari response backend
          final responseData = e.response?.data;
          if (responseData is Map && responseData['message'] != null) {
            errorMessage = responseData['message'].toString();
          } else {
            errorMessage = e.message ?? 'Login gagal';
          }
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

  Future<User?> _getCachedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(_userKey);
    if (userJson == null || userJson.isEmpty) return null;

    try {
      final decoded = jsonDecode(userJson);
      if (decoded is Map<String, dynamic>) {
        return User.fromJson(decoded);
      }
      if (decoded is Map) {
        return User.fromJson(Map<String, dynamic>.from(decoded));
      }
    } catch (e) {
      debugPrint('[AuthService] Failed to decode cached user: $e');
      final legacyMap = _LegacyMapParser.parse(userJson);
      if (legacyMap != null) {
        try {
          final user = User.fromJson(legacyMap);
          await _saveUser(user);
          return user;
        } catch (legacyError) {
          debugPrint('[AuthService] Failed to parse legacy cached user: $legacyError');
        }
      }
    }
    return null;
  }

  Future<User?> _getLegacyCachedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final legacyJson = prefs.getString(_legacyUserKey);
    if (legacyJson == null || legacyJson.isEmpty) return null;

    try {
      final decoded = jsonDecode(legacyJson);
      if (decoded is Map<String, dynamic>) {
        return User.fromJson(decoded);
      }
      if (decoded is Map) {
        return User.fromJson(Map<String, dynamic>.from(decoded));
      }
    } catch (e) {
      debugPrint('[AuthService] Failed to decode legacy cached user: $e');
    }
    return null;
  }

  Future<User?> getCachedUserOnly() async {
    return await _getCachedUser() ?? await _getLegacyCachedUser();
  }

  Future<User?> getCurrentUser() async {
    final cachedUser = await getCachedUserOnly();

    try {
      // Verifikasi session dengan backend
      final response = await _apiService.get(ApiConfig.session);
      if (response.statusCode == 200 && response.data['data'] != null) {
        final userData = response.data['data'];
        debugPrint('[AuthService] User data from session: name="${userData['name']}", email="${userData['email']}"');
        final user = User.fromJson(userData);
        debugPrint('[AuthService] Parsed user: name="${user.name}", email="${user.email}"');
        await _saveUser(user);
        return user;
      }
      // Session expired atau tidak valid
      if (response.statusCode == 401 || response.statusCode == 403) {
        // Clear local data
        await logout();
        return null;
      }
      return cachedUser;
    } catch (e) {
      // Jika error karena session expired, clear local data
      if (e is DioException) {
        final statusCode = e.response?.statusCode;
        if (statusCode == 401 || statusCode == 403) {
          await logout();
          return null;
        }
        if (cachedUser != null) {
          debugPrint('[AuthService] Using cached user (offline mode).');
          return cachedUser;
        }
      }
      return cachedUser;
    }
  }

  /// Request password reset - kirim OTP ke email
  Future<Map<String, dynamic>> requestPasswordReset(String email) async {
    try {
      // Normalize email: trim (untuk NIK KTP, tidak lowercase karena bisa angka)
      // Backend akan handle lowercase untuk email dan normalization untuk NIK
      final normalizedEmail = email.trim();
      
      final response = await _apiService.post(
        ApiConfig.forgotPassword,
        data: {
          'email': normalizedEmail, // Bisa berupa email atau NIK KTP
        },
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': response.data['message'] ?? 'OTP telah dikirim ke email Anda',
          'email': response.data['email'], // ✅ Email dari backend (jika input NIK, ini adalah email user yang terkait)
        };
      } else {
        // ✅ Handle semua status code error (400, 404, 500, dll)
        // Throw DioException agar error handling di catch block bisa mengambil message dari response
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.badResponse,
        );
      }
    } catch (e) {
      String errorMessage = 'Gagal mengirim OTP';
      if (e is DioException) {
        if (e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.sendTimeout) {
          errorMessage = 'Koneksi timeout. Pastikan backend server berjalan dan dapat diakses.';
        } else if (e.type == DioExceptionType.connectionError) {
          errorMessage = 'Tidak dapat terhubung ke server. Pastikan backend server berjalan.';
        } else {
          // ✅ Ambil error message dari response backend
          final responseData = e.response?.data;
          if (responseData is Map && responseData['message'] != null) {
            errorMessage = responseData['message'].toString();
          } else {
            errorMessage = e.message ?? 'Gagal mengirim OTP';
          }
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

  /// Verify OTP code
  Future<Map<String, dynamic>> verifyOTP(String email, String otpCode) async {
    try {
      // Normalize email: trim and lowercase (sama seperti di backend)
      final normalizedEmail = email.trim().toLowerCase();
      
      final response = await _apiService.post(
        ApiConfig.verifyOTP,
        data: {
          'email': normalizedEmail,
          'otp': otpCode.trim(),
        },
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': response.data['message'] ?? 'OTP berhasil diverifikasi',
        };
      } else {
        throw Exception(response.data['message'] ?? 'OTP tidak valid');
      }
    } catch (e) {
      String errorMessage = 'OTP tidak valid';
      if (e is DioException) {
        if (e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.sendTimeout) {
          errorMessage = 'Koneksi timeout. Pastikan backend server berjalan dan dapat diakses.';
        } else if (e.type == DioExceptionType.connectionError) {
          errorMessage = 'Tidak dapat terhubung ke server. Pastikan backend server berjalan.';
        } else {
          // ✅ Ambil error message dari response backend
          final responseData = e.response?.data;
          if (responseData is Map && responseData['message'] != null) {
            errorMessage = responseData['message'].toString();
          } else {
            errorMessage = e.message ?? 'OTP tidak valid';
          }
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

  /// Reset password dengan OTP yang sudah diverifikasi
  Future<Map<String, dynamic>> resetPassword(String email, String otpCode, String newPassword) async {
    try {
      final response = await _apiService.post(
        ApiConfig.resetPassword,
        data: {
          'email': email,
          'otp': otpCode,
          'password': newPassword,
        },
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': response.data['message'] ?? 'Password berhasil direset',
        };
      } else {
        throw Exception(response.data['message'] ?? 'Gagal mereset password');
      }
    } catch (e) {
      String errorMessage = 'Gagal mereset password';
      if (e is DioException) {
        if (e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.sendTimeout) {
          errorMessage = 'Koneksi timeout. Pastikan backend server berjalan dan dapat diakses.';
        } else if (e.type == DioExceptionType.connectionError) {
          errorMessage = 'Tidak dapat terhubung ke server. Pastikan backend server berjalan.';
        } else {
          // ✅ Ambil error message dari response backend
          final responseData = e.response?.data;
          if (responseData is Map && responseData['message'] != null) {
            errorMessage = responseData['message'].toString();
          } else {
            errorMessage = e.message ?? 'Gagal mereset password';
          }
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

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isLoggedInKey) ?? false;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
    await prefs.remove(_legacyUserKey);
    await prefs.remove(_isLoggedInKey);
    await prefs.remove('cookies');
  }

  Future<void> _saveUser(User user) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = user.toJson();
    await prefs.setString(_userKey, jsonEncode(payload));
    await prefs.setString(_legacyUserKey, jsonEncode({
      'id': user.id,
      'name': user.name,
      'email': user.email,
      'role': user.role,
      'team': user.team,
      'title': user.title,
      'avatarColor': user.avatarColor,
      'photoUrl': user.photoUrl,
      'externalId': user.externalId,
      'phone': user.phone,
      'siteId': user.siteId,
      'site': user.site?.toJson(),
      'positionId': user.positionId,
      'position': user.position?.toJson(),
      'hasPassword': user.hasPassword,
      'needsPasswordChange': user.needsPasswordChange,
    }));
  }

  Future<void> _setLoggedIn(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isLoggedInKey, value);
  }
}

class _LegacyMapParser {
  _LegacyMapParser(this._input);

  final String _input;
  int _index = 0;

  static Map<String, dynamic>? parse(String input) {
    final parser = _LegacyMapParser(input.trim());
    return parser._parseMap();
  }

  Map<String, dynamic>? _parseMap() {
    _skipSpaces();
    if (!_consumeChar('{')) return null;

    final result = <String, dynamic>{};
    while (_index < _input.length) {
      _skipSpaces();
      if (_peekChar() == '}') {
        _index++;
        break;
      }

      final key = _readUntil(':');
      if (key == null) return null;
      final trimmedKey = key.trim();
      if (!_consumeChar(':')) return null;

      _skipSpaces();
      dynamic value;
      if (_peekChar() == '{') {
        value = _parseMap();
      } else {
        final rawValue = _readValueToken();
        value = _parsePrimitive(rawValue.trim());
      }

      if (trimmedKey.isNotEmpty) {
        result[trimmedKey] = value;
      }

      _skipSpaces();
      if (_peekChar() == ',') {
        _index++;
      } else if (_peekChar() == '}') {
        _index++;
        break;
      }
    }

    return result;
  }

  String? _readUntil(String delimiter) {
    final start = _index;
    while (_index < _input.length && _input[_index] != delimiter) {
      _index++;
    }
    if (_index >= _input.length) return null;
    return _input.substring(start, _index);
  }

  String _readValueToken() {
    final start = _index;
    int braceDepth = 0;

    while (_index < _input.length) {
      final char = _input[_index];
      if (char == '{') {
        braceDepth++;
      } else if (char == '}') {
        if (braceDepth == 0) break;
        braceDepth--;
      } else if (char == ',' && braceDepth == 0) {
        break;
      }
      _index++;
    }

    return _input.substring(start, _index);
  }

  dynamic _parsePrimitive(String value) {
    if (value.isEmpty) return '';
    if (value == 'null') return null;
    if (value == 'true') return true;
    if (value == 'false') return false;

    final intValue = int.tryParse(value);
    if (intValue != null) return intValue;

    final doubleValue = double.tryParse(value);
    if (doubleValue != null) return doubleValue;

    return value;
  }

  void _skipSpaces() {
    while (_index < _input.length && _input[_index].trim().isEmpty) {
      _index++;
    }
  }

  bool _consumeChar(String char) {
    if (_peekChar() == char) {
      _index++;
      return true;
    }
    return false;
  }

  String? _peekChar() {
    if (_index >= _input.length) return null;
    return _input[_index];
  }
}

