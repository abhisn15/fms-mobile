import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConfig {
  // Load from environment variables
  // Default values for development if .env is not loaded
  static String get baseUrl {
    final envUrl = dotenv.env['API_BASE_URL'];
    
    if (envUrl != null && envUrl.isNotEmpty) {
      // Remove trailing slash if exists
      var cleanUrl = envUrl.trim().replaceAll(RegExp(r'/$'), '');
      
      // Auto-fix common typos
      if (cleanUrl.contains('tpm-faciity.com')) {
        cleanUrl = cleanUrl.replaceAll('tpm-faciity.com', 'tpm-facility.com');
      }
      
      // Validate URL format
      if (!cleanUrl.startsWith('http://') && !cleanUrl.startsWith('https://')) {
        cleanUrl = 'https://$cleanUrl';
      }
      
      return cleanUrl;
    }
    
    // Default untuk Android Emulator
    return 'http://10.0.2.2:3001';
  }
  
  static String get gcsBucketName {
    return dotenv.env['GCS_BUCKET_NAME'] ?? 'mms.mindotek.com';
  }
  
  // API Endpoints
  static const String login = '/api/auth/login';
  static const String session = '/api/session';
  
  // Employee endpoints
  static const String attendance = '/api/ess/attendance';
  static const String checkIn = '/api/ess/attendance/check-in';
  static const String checkOut = '/api/ess/attendance/check-out';
  static const String shifts = '/api/ess/shifts';
  static const String activity = '/api/ess/activity';
  static String activityById(String id) => '/api/ess/activity/$id';
  static const String checkpointPhoto = '/api/ess/activity/checkpoint-photo';
  static const String requests = '/api/ess/requests';
  static const String profile = '/api/ess/profile';
  static const String setPassword = '/api/ess/profile/set-password';
  static const String realtimeLog = '/api/supervisor/attendance/realtime/log';
  static const String clientErrorLog = '/api/ess/client-logs';
  
  // Helper methods
  static String getFullUrl(String endpoint) {
    return '$baseUrl$endpoint';
  }
  
  /// Convert relative URL to full URL
  /// Priority: Google Cloud Storage URL (storage.googleapis.com) > Full URL > Relative URL
  /// 
  /// Backend should return full GCS URL: https://storage.googleapis.com/bucket-name/path/to/file.webp
  /// If URL is relative (/uploads/...), it means backend is using local fallback
  /// In that case, we can try to convert to GCS URL if we know the path structure
  static String getImageUrl(String? url) {
    if (url == null || url.isEmpty) {
      return '';
    }
    
    // If already a full URL (including GCS), return as is
    // This is the preferred format - backend should return this
    if (url.startsWith('http://') || url.startsWith('https://')) {
      // Check if it's a GCS URL
      if (url.contains('storage.googleapis.com')) {
        return url;
      }
      // Other full URLs (CDN, etc)
      return url;
    }
    
    // If relative URL starting with /uploads/, it's local fallback
    // Use baseUrl directly (don't convert to GCS URL since file is stored locally)
    // Local: /uploads/activities/user/timestamp/file.webp
    // Should return: https://your-domain.com/uploads/activities/user/timestamp/file.webp
    if (url.startsWith('/uploads/')) {
      // For local storage, just prepend baseUrl
      return '$baseUrl$url';
    }
    
    // If relative URL (starts with /) but not /uploads/, prepend baseUrl
    if (url.startsWith('/')) {
      return '$baseUrl$url';
    }
    
    // If it's a GCS path without protocol (e.g., "checkins/user/timestamp/file.webp")
    // Construct full GCS URL
    if (url.contains('/') && !url.startsWith('uploads/')) {
      return 'https://storage.googleapis.com/$gcsBucketName/$url';
    }
    
    // Otherwise, assume it's relative and prepend baseUrl with /
    return '$baseUrl/$url';
  }
}

