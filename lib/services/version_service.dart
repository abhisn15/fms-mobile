import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../config/api_config.dart';
import '../models/version_model.dart';
import 'api_service.dart';

class VersionService {
  final ApiService _apiService = ApiService();

  /// Check for app updates
  Future<VersionResponse> checkForUpdates() async {
    try {
      final platform = Platform.isAndroid ? 'android' : 'ios';

      final response = await _apiService.get(
        '${ApiConfig.version}?platform=$platform',
      );

      if (response.statusCode == 200) {
        return VersionResponse.fromJson(response.data);
      } else {
        return VersionResponse(
          success: false,
          error: 'Failed to check for updates: ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('[VersionService] Error checking for updates: $e');
      return VersionResponse(
        success: false,
        error: 'Network error while checking for updates',
      );
    }
  }

  /// Get current app version from package info (pubspec.yaml)
  Future<String> getCurrentAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final version = packageInfo.version; // e.g., "1.1.13"
      debugPrint('[VersionService] Current app version: $version');
      return version;
    } catch (e) {
      debugPrint('[VersionService] Error getting current app version: $e');
      // Fallback to hardcoded version if package_info fails
      return '1.1.14';
    }
  }

  /// Check if update is available
  Future<UpdateCheckResult> checkUpdateAvailability() async {
    try {
      final currentVersion = await getCurrentAppVersion();

      final versionResponse = await checkForUpdates();
      if (!versionResponse.success || versionResponse.data == null) {
        return UpdateCheckResult(
          updateAvailable: false,
          updateRequired: false,
          currentVersion: currentVersion,
          error: versionResponse.error,
        );
      }

      final serverVersion = versionResponse.data!;

      final updateAvailable = serverVersion.isUpdateAvailable(currentVersion);
      final updateRequired = serverVersion.isUpdateRequired(currentVersion);

      return UpdateCheckResult(
        updateAvailable: updateAvailable,
        updateRequired: updateRequired,
        serverVersion: serverVersion,
        currentVersion: currentVersion,
      );
    } catch (e) {
      debugPrint('[VersionService] Error checking update availability: $e');
      final currentVersion = await getCurrentAppVersion();
      return UpdateCheckResult(
        updateAvailable: false,
        updateRequired: false,
        currentVersion: currentVersion,
        error: 'Failed to check for updates',
      );
    }
  }
}

class UpdateCheckResult {
  final bool updateAvailable;
  final bool updateRequired;
  final VersionData? serverVersion;
  final String currentVersion;
  final String? error;

  UpdateCheckResult({
    required this.updateAvailable,
    required this.updateRequired,
    this.serverVersion,
    required this.currentVersion,
    this.error,
  });

  bool get hasError => error != null;
}
