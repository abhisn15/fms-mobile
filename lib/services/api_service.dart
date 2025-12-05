import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

/// Callback untuk handle session expired
typedef SessionExpiredCallback = void Function();

class ApiService {
  late Dio _dio;
  static final ApiService _instance = ApiService._internal();
  SessionExpiredCallback? _onSessionExpired;
  bool _isLoggingOut = false; // Prevent multiple logout calls
  
  factory ApiService() => _instance;
  
  /// Set callback untuk handle session expired
  void setSessionExpiredCallback(SessionExpiredCallback callback) {
    _onSessionExpired = callback;
    debugPrint('[ApiService] Session expired callback registered');
  }
  
  ApiService._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 60), // Increase timeout untuk development
      receiveTimeout: const Duration(seconds: 60),
      headers: {
        'Content-Type': 'application/json',
      },
    ));

    // Add interceptor untuk menambahkan cookies
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        debugPrint('[API] → ${options.method} ${options.path}');
        if (options.queryParameters.isNotEmpty) {
          debugPrint('[API] Query params: ${options.queryParameters}');
        }
        // Ambil cookies dari shared preferences
        final prefs = await SharedPreferences.getInstance();
        final cookies = prefs.getString('cookies');
        if (cookies != null && cookies.isNotEmpty) {
          options.headers['Cookie'] = cookies;
          debugPrint('[API] Cookie attached');
        }
        handler.next(options);
      },
      onResponse: (response, handler) async {
        debugPrint('[API] ← ${response.statusCode} ${response.requestOptions.path}');
        
        // Check for session expired in response (401/403)
        if (response.statusCode == 401 || response.statusCode == 403) {
          debugPrint('[API] ⚠ Session expired ($response.statusCode) in response. Triggering auto logout...');
          // Trigger auto logout callback (only once)
          if (_onSessionExpired != null && !_isLoggingOut) {
            _isLoggingOut = true;
            _onSessionExpired!();
          }
        }
        
        if (response.statusCode != null && response.statusCode! >= 400) {
          debugPrint('[API] Error Response: ${response.data}');
        }
        // Simpan cookies dari response
        final cookies = response.headers.value('set-cookie');
        if (cookies != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('cookies', cookies);
          debugPrint('[API] Cookie saved');
        }
        handler.next(response);
      },
      onError: (error, handler) {
        debugPrint('[API] ✗ ERROR: ${error.type} - ${error.requestOptions.path}');
        if (error.response != null) {
          final statusCode = error.response?.statusCode;
          debugPrint('[API] Error Status: $statusCode');
          debugPrint('[API] Error Data: ${error.response?.data}');
          
          // Handle session expired (401 Unauthorized atau 403 Forbidden)
          if (statusCode == 401 || statusCode == 403) {
            debugPrint('[API] ⚠ Session expired ($statusCode). Triggering auto logout...');
            // Trigger auto logout callback (only once)
            if (_onSessionExpired != null && !_isLoggingOut) {
              _isLoggingOut = true;
              _onSessionExpired!();
            }
          }
        } else {
          debugPrint('[API] Error Message: ${error.message}');
        }
        // Handle connection timeout dengan pesan yang lebih jelas
        if (error.type == DioExceptionType.connectionTimeout ||
            error.type == DioExceptionType.receiveTimeout ||
            error.type == DioExceptionType.sendTimeout) {
          error = DioException(
            requestOptions: error.requestOptions,
            response: error.response,
            type: error.type,
            error: 'Koneksi timeout. Pastikan backend server berjalan di port 3001 dan dapat diakses.',
          );
        } else if (error.type == DioExceptionType.connectionError) {
          error = DioException(
            requestOptions: error.requestOptions,
            response: error.response,
            type: error.type,
            error: 'Tidak dapat terhubung ke server. Pastikan backend berjalan di http://localhost:3001',
          );
        }
        handler.next(error);
      },
    ));
  }

  // GET request
  Future<Response> get(String endpoint, {Map<String, dynamic>? queryParameters}) async {
    try {
      final response = await _dio.get(
        endpoint,
        queryParameters: queryParameters,
        options: Options(
          followRedirects: false,
          validateStatus: (status) => status! < 600, // Allow 500-level errors for custom handling
        ),
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  // POST request dengan JSON
  Future<Response> post(String endpoint, {Map<String, dynamic>? data}) async {
    try {
      final response = await _dio.post(
        endpoint,
        data: data,
        options: Options(
          followRedirects: false,
          validateStatus: (status) => status! < 600, // Allow 500-level errors for custom handling
        ),
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  // POST request dengan FormData (untuk upload file)
  Future<Response> postFormData(String endpoint, FormData formData) async {
    try {
      final response = await _dio.post(
        endpoint,
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
          followRedirects: false,
          validateStatus: (status) => status! < 600, // Allow 500-level errors for custom handling
        ),
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  // PUT request dengan JSON
  Future<Response> put(String endpoint, {Map<String, dynamic>? data}) async {
    try {
      final response = await _dio.put(
        endpoint,
        data: data,
        options: Options(
          followRedirects: false,
          validateStatus: (status) => status! < 600,
        ),
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  // PUT request dengan FormData (untuk update dengan file)
  Future<Response> putFormData(String endpoint, FormData formData) async {
    try {
      final response = await _dio.put(
        endpoint,
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
          followRedirects: false,
          validateStatus: (status) => status! < 600,
        ),
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  // DELETE request
  Future<Response> delete(String endpoint) async {
    try {
      final response = await _dio.delete(
        endpoint,
        options: Options(
          followRedirects: false,
          validateStatus: (status) => status! < 600,
        ),
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }
}

