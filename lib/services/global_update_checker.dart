import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'version_service.dart';
import '../models/version_model.dart';
import '../widgets/update_dialog.dart';

class GlobalUpdateChecker {
  static const String _lastUpdateCheckKey = 'last_update_check';
  static const Duration _minCheckInterval = Duration(minutes: 5);

  static DateTime? _lastCheckAt;
  static bool _loadedFromPrefs = false;

  /// Start update checking (run once when entering dashboard)
  static void startAutoCheck(BuildContext context) {
    _performUpdateCheck(context);
  }

  /// Trigger update check manually (used by route observer)
  static Future<void> checkNow(BuildContext context) async {
    await _performUpdateCheck(context);
  }

  /// Stop automatic checking (kept for compatibility)
  static void stopAutoCheck() {}

  /// Manual update check (for settings screen)
  static Future<void> manualUpdateCheck(BuildContext context) async {
    await _performUpdateCheck(context, forceShow: true);
  }

  /// Perform the actual update check
  static Future<void> _performUpdateCheck(BuildContext context, {bool forceShow = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (!_loadedFromPrefs) {
        final lastCheck = prefs.getString(_lastUpdateCheckKey);
        if (lastCheck != null) {
          _lastCheckAt = DateTime.tryParse(lastCheck) ?? _lastCheckAt;
        }
        _loadedFromPrefs = true;
      }

      if (!forceShow && _lastCheckAt != null) {
        final elapsed = DateTime.now().difference(_lastCheckAt!);
        if (elapsed < _minCheckInterval) {
          debugPrint('[GlobalUpdateChecker] Skip check (throttled)');
          return;
        }
      }

      debugPrint('[GlobalUpdateChecker] Checking for updates...');

      final updateCheck = await VersionService().checkUpdateAvailability();

      if (updateCheck.updateAvailable && updateCheck.serverVersion != null) {
        debugPrint('[GlobalUpdateChecker] Update available: ${updateCheck.serverVersion!.version}');

        // Show dialog if context is still valid
        if (context.mounted) {
          await UpdateDialog.show(
            context: context,
            versionData: updateCheck.serverVersion!,
            isRequired: true,
          );
        }
      } else {
        debugPrint('[GlobalUpdateChecker] No update available or already up to date');
      }

      // Update last check timestamp
      _lastCheckAt = DateTime.now();
      await prefs.setString(_lastUpdateCheckKey, DateTime.now().toIso8601String());

    } catch (e) {
      debugPrint('[GlobalUpdateChecker] Error checking for updates: $e');
    }
  }

  /// Reset update dialog state (for testing)
  static Future<void> resetUpdateDialogState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastUpdateCheckKey);
    debugPrint('[GlobalUpdateChecker] Update dialog state reset');
  }

  /// Get last update check info
  static Future<Map<String, String?>> getUpdateCheckInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final lastCheck = prefs.getString(_lastUpdateCheckKey);

    return {
      'lastCheck': lastCheck,
    };
  }
}

class VersionCheckObserver extends NavigatorObserver {
  void _trigger(NavigatorState? navigator) {
    if (navigator == null) return;
    final context = navigator.context;
    GlobalUpdateChecker.checkNow(context);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _trigger(navigator);
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _trigger(navigator);
    super.didPop(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _trigger(navigator);
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }
}








