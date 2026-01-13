import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'version_service.dart';
import '../models/version_model.dart';
import '../widgets/update_dialog.dart';

class GlobalUpdateChecker {
  static const String _lastUpdateCheckKey = 'last_update_check';
  static const String _updateShownKey = 'update_dialog_shown';
  static const Duration _checkInterval = Duration(hours: 6); // Check every 6 hours

  static Timer? _checkTimer;

  /// Start automatic update checking
  static void startAutoCheck(BuildContext context) {
    // Initial check
    _performUpdateCheck(context);

    // Periodic check every 6 hours
    _checkTimer?.cancel();
    _checkTimer = Timer.periodic(_checkInterval, (_) {
      if (context.mounted) {
        _performUpdateCheck(context);
      }
    });
  }

  /// Stop automatic checking
  static void stopAutoCheck() {
    _checkTimer?.cancel();
    _checkTimer = null;
  }

  /// Manual update check (for settings screen)
  static Future<void> manualUpdateCheck(BuildContext context) async {
    await _performUpdateCheck(context, forceShow: true);
  }

  /// Perform the actual update check
  static Future<void> _performUpdateCheck(BuildContext context, {bool forceShow = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Check if we should skip (already shown recently and not forced)
      if (!forceShow) {
        final lastShown = prefs.getString(_updateShownKey);
        if (lastShown != null) {
          final lastShownDate = DateTime.tryParse(lastShown);
          if (lastShownDate != null) {
            final now = DateTime.now();
            // Don't show again if already shown today
            if (lastShownDate.year == now.year &&
                lastShownDate.month == now.month &&
                lastShownDate.day == now.day) {
              debugPrint('[GlobalUpdateChecker] Update dialog already shown today, skipping');
              return;
            }
          }
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
            isRequired: updateCheck.updateRequired,
          );

          // Mark as shown today
          await prefs.setString(_updateShownKey, DateTime.now().toIso8601String());
          debugPrint('[GlobalUpdateChecker] Update dialog shown and marked as displayed');
        }
      } else {
        debugPrint('[GlobalUpdateChecker] No update available or already up to date');
      }

      // Update last check timestamp
      await prefs.setString(_lastUpdateCheckKey, DateTime.now().toIso8601String());

    } catch (e) {
      debugPrint('[GlobalUpdateChecker] Error checking for updates: $e');
    }
  }

  /// Reset update dialog state (for testing)
  static Future<void> resetUpdateDialogState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_updateShownKey);
    await prefs.remove(_lastUpdateCheckKey);
    debugPrint('[GlobalUpdateChecker] Update dialog state reset');
  }

  /// Get last update check info
  static Future<Map<String, String?>> getUpdateCheckInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final lastCheck = prefs.getString(_lastUpdateCheckKey);
    final lastShown = prefs.getString(_updateShownKey);

    return {
      'lastCheck': lastCheck,
      'lastShown': lastShown,
    };
  }
}













