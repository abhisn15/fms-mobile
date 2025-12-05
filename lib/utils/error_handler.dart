import 'package:dio/dio.dart';

class ErrorHandler {
  /// Convert DioException atau Exception lainnya menjadi pesan error yang user-friendly
  static String getErrorMessage(dynamic error) {
    if (error is DioException) {
      // Handle berdasarkan tipe error
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.sendTimeout:
          return 'Koneksi timeout. Pastikan koneksi internet Anda stabil dan coba lagi.';
        
        case DioExceptionType.connectionError:
          return 'Tidak dapat terhubung ke server. Pastikan koneksi internet Anda aktif.';
        
        case DioExceptionType.badResponse:
          // Handle berdasarkan status code
          final statusCode = error.response?.statusCode;
          if (statusCode != null) {
            switch (statusCode) {
              case 400:
                return 'Permintaan tidak valid. Silakan periksa data yang Anda masukkan.';
              case 401:
                return 'Sesi Anda telah berakhir. Silakan login kembali.';
              case 403:
                return 'Anda tidak memiliki izin untuk melakukan aksi ini.';
              case 404:
                return 'Data tidak ditemukan.';
              case 500:
                return 'Terjadi kesalahan pada server. Silakan coba lagi beberapa saat atau hubungi administrator.';
              case 502:
              case 503:
              case 504:
                return 'Server sedang dalam perawatan. Silakan coba lagi beberapa saat.';
              default:
                // Coba ambil pesan error dari response body
                final errorMessage = error.response?.data?['message'] ?? 
                                   error.response?.data?['error'];
                if (errorMessage != null && errorMessage is String) {
                  return errorMessage;
                }
                return 'Terjadi kesalahan (Status: $statusCode). Silakan coba lagi.';
            }
          }
          return 'Terjadi kesalahan pada server. Silakan coba lagi.';
        
        case DioExceptionType.cancel:
          return 'Permintaan dibatalkan.';
        
        case DioExceptionType.unknown:
        default:
          // Cek apakah ada pesan error yang lebih spesifik
          final errorMessage = error.response?.data?['message'] ?? 
                             error.response?.data?['error'];
          if (errorMessage != null && errorMessage is String) {
            return errorMessage;
          }
          return 'Terjadi kesalahan yang tidak diketahui. Silakan coba lagi.';
      }
    } else if (error is String) {
      // Jika sudah berupa string, kembalikan langsung
      return error;
    } else {
      // Untuk Exception lainnya
      final errorString = error.toString();
      
      // Filter pesan error yang terlalu teknis
      if (errorString.contains('DioException')) {
        return 'Terjadi kesalahan pada koneksi. Silakan coba lagi.';
      }
      
      // Hapus prefix "Exception: " jika ada
      return errorString.replaceAll('Exception: ', '').replaceAll('Error: ', '');
    }
  }
  
  /// Check apakah error adalah error koneksi (bukan server error)
  static bool isConnectionError(dynamic error) {
    if (error is DioException) {
      return error.type == DioExceptionType.connectionTimeout ||
             error.type == DioExceptionType.receiveTimeout ||
             error.type == DioExceptionType.sendTimeout ||
             error.type == DioExceptionType.connectionError;
    }
    return false;
  }
  
  /// Check apakah error adalah server error (5xx)
  static bool isServerError(dynamic error) {
    if (error is DioException && error.response != null) {
      final statusCode = error.response!.statusCode;
      return statusCode != null && statusCode >= 500 && statusCode < 600;
    }
    return false;
  }
}

