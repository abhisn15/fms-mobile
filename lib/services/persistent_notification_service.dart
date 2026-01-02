import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/attendance_model.dart';

class PersistentNotificationService {
  static const String _channelId = 'checkin_status';
  static const String _channelName = 'Status Check-in';
  static const String _channelDescription = 'Notifikasi status check-in aktif';
  static const int _notificationId = 999; // Unique ID for persistent notification

  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static bool _isInitialized = false;

  /// Initialize notification service
  static Future<void> initialize() async {
    if (_isInitialized) return;

    // Initialize settings
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initializationSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channel for Android
    if (defaultTargetPlatform == TargetPlatform.android) {
      await _createNotificationChannel();
    }

    _isInitialized = true;
    debugPrint('[PersistentNotification] Service initialized');
  }

  /// Create notification channel for Android
  static Future<void> _createNotificationChannel() async {
    const androidChannel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.max,
      showBadge: true,
      enableVibration: true,
      enableLights: true,
      playSound: false, // No sound for persistent notification
    );

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  /// Show persistent check-in notification
  static Future<void> showCheckInNotification(AttendanceRecord todayRecord) async {
    await initialize();

    final checkInTime = _formatTime(todayRecord.checkIn);
    final duration = _calculateDuration(todayRecord.checkIn);

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.max,
      ongoing: true, // Makes it persistent/non-dismissible
      autoCancel: false,
      showWhen: false,
      enableVibration: false,
      playSound: false,
      icon: '@mipmap/ic_launcher',
      styleInformation: BigTextStyleInformation(
        'Check-in aktif sejak $checkInTime\nDurasi: $duration\n\nTap untuk buka aplikasi',
        contentTitle: '🔴 Check-in Aktif',
        summaryText: 'Status absensi Anda',
      ),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: false,
      presentBadge: true,
      presentSound: false,
      threadIdentifier: 'checkin_status',
      categoryIdentifier: 'checkin_status',
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      _notificationId,
      '🔴 Check-in Aktif',
      'Check-in sejak $checkInTime\nDurasi: $duration',
      notificationDetails,
    );

    debugPrint('[PersistentNotification] Check-in notification shown');
  }

  /// Update existing check-in notification with current duration
  static Future<void> updateCheckInNotification(AttendanceRecord todayRecord) async {
    if (todayRecord.checkIn == null) return;

    await showCheckInNotification(todayRecord);
    debugPrint('[PersistentNotification] Check-in notification updated');
  }

  /// Hide persistent check-in notification (when check-out)
  static Future<void> hideCheckInNotification() async {
    await _notificationsPlugin.cancel(_notificationId);
    debugPrint('[PersistentNotification] Check-in notification hidden');
  }

  /// Check if persistent notification is currently shown
  static Future<bool> isNotificationVisible() async {
    // This is a simple check - in a real app you might want to track state
    // For now, we'll assume it's visible if there's an active check-in
    return true;
  }

  /// Handle notification tap
  static void _onNotificationTapped(NotificationResponse response) {
    debugPrint('[PersistentNotification] Notification tapped: ${response.payload}');
    // Handle notification tap - could navigate to home screen or attendance screen
  }

  /// Format time for display
  static String _formatTime(String? dateTimeString) {
    if (dateTimeString == null) return 'Unknown';

    try {
      // If it's already in HH:MM format, return as is
      if (dateTimeString.contains(':') && !dateTimeString.contains('T') && !dateTimeString.contains('-')) {
        return dateTimeString;
      }

      // Parse full datetime format
      final dateTime = DateTime.parse(dateTimeString);
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      debugPrint('[PersistentNotification] Error formatting time: $e');
      return 'Unknown';
    }
  }

  /// Calculate duration since check-in
  static String _calculateDuration(String? checkInTime) {
    if (checkInTime == null) return 'Unknown';

    try {
      DateTime checkIn;

      // Handle different time formats
      if (checkInTime.contains('T') || checkInTime.contains('-')) {
        // ISO format or full date format
        checkIn = DateTime.parse(checkInTime);
      } else if (checkInTime.contains(':')) {
        // HH:MM format - assume today's date
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final timeParts = checkInTime.split(':');
        if (timeParts.length >= 2) {
          final hour = int.tryParse(timeParts[0]) ?? 0;
          final minute = int.tryParse(timeParts[1]) ?? 0;
          checkIn = DateTime(today.year, today.month, today.day, hour, minute);
        } else {
          return 'Unknown';
        }
      } else {
        return 'Unknown';
      }

      final now = DateTime.now();
      final difference = now.difference(checkIn);

      final hours = difference.inHours;
      final minutes = difference.inMinutes.remainder(60);

      if (hours > 0) {
        return '${hours}j ${minutes}m';
      } else {
        return '${minutes}m';
      }
    } catch (e) {
      debugPrint('[PersistentNotification] Error calculating duration: $e');
      return 'Unknown';
    }
  }

  /// Start periodic updates for notification (every 30 seconds for near real-time duration)
  static Timer? _updateTimer;
  static void startPeriodicUpdates(AttendanceRecord todayRecord) {
    stopPeriodicUpdates(); // Stop any existing timer

    _updateTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      updateCheckInNotification(todayRecord);
    });

    debugPrint('[PersistentNotification] Periodic updates started (every 30 seconds)');
  }

  /// Stop periodic updates
  static void stopPeriodicUpdates() {
    _updateTimer?.cancel();
    _updateTimer = null;
    debugPrint('[PersistentNotification] Periodic updates stopped');
  }

  /// Clean up resources
  static void dispose() {
    stopPeriodicUpdates();
    debugPrint('[PersistentNotification] Service disposed');
  }
}
