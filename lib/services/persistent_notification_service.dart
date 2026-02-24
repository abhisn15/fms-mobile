import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/attendance_model.dart';
import '../models/shift_model.dart';

class PersistentNotificationService {
  static const String _channelId = 'checkin_status';
  static const String _channelName = 'Status Check-in';
  static const String _channelDescription = 'Notifikasi status check-in aktif';
  static const int _notificationId = 999; // Unique ID for persistent notification
  static const Duration _updateInterval = Duration(minutes: 5); // Update notification every 5 minutes

  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static bool _isInitialized = false;
  static DailyShift? _currentShift;

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
  static Future<void> showCheckInNotification(
    AttendanceRecord todayRecord, {
    DailyShift? shift,
  }) async {
    await initialize();

    if (shift != null) {
      _currentShift = shift;
    }

    final checkInTime = _formatTime(todayRecord.checkIn);
    final duration = _calculateDuration(todayRecord);
    final shiftLabel = _buildShiftLabel(_currentShift);
    final checkoutLabel = _buildShiftCheckoutLabel(todayRecord, _currentShift);
    final reminderLine = _buildCheckoutReminderLine(todayRecord, _currentShift);

    final contentLines = <String>[
      'Check-in sejak $checkInTime',
      if (shiftLabel != null) 'Shift: $shiftLabel',
      if (checkoutLabel != null) 'Checkout: $checkoutLabel',
      if (reminderLine != null) reminderLine,
      'Durasi: $duration',
      '',
      'Tap untuk buka aplikasi',
    ];

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.max,
      ongoing: true, // Makes it persistent/non-dismissible
      autoCancel: false,
      onlyAlertOnce: true,
      showWhen: false,
      enableVibration: false,
      playSound: false,
      icon: '@mipmap/ic_launcher',
      styleInformation: BigTextStyleInformation(
        contentLines.join('\n'),
        contentTitle: 'Check-in Aktif',
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
      'Check-in Aktif',
      'Check-in sejak $checkInTime',
      notificationDetails,
    );

    debugPrint('[PersistentNotification] Check-in notification shown');
  }

  /// Update existing check-in notification with current duration
  static Future<void> updateCheckInNotification(
    AttendanceRecord todayRecord, {
    DailyShift? shift,
  }) async {
    if (todayRecord.checkIn == null) return;

    // Update stored record for periodic updates
    _currentRecord = todayRecord;
    if (shift != null) {
      _currentShift = shift;
    }

    await showCheckInNotification(todayRecord, shift: _currentShift);
    debugPrint('[PersistentNotification] Check-in notification updated');
  }

  /// Hide persistent check-in notification (when check-out)
  static Future<void> hideCheckInNotification() async {
    await _notificationsPlugin.cancel(_notificationId);
    _currentShift = null;
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
  static String _calculateDuration(AttendanceRecord record) {
    final checkInTime = record.checkIn;
    if (checkInTime == null) return 'Unknown';

    try {
      DateTime checkIn;

      // Handle different time formats
      if (checkInTime.contains('T') || checkInTime.contains('-')) {
        // ISO format or full date format
        checkIn = DateTime.parse(checkInTime);
      } else if (checkInTime.contains(':')) {
        // HH:MM format - use original check-in date when provided by backend
        final now = DateTime.now();
        DateTime baseDate;
        try {
          final rawDate =
              (record.originalCheckInDate != null &&
                  record.originalCheckInDate!.trim().isNotEmpty)
              ? record.originalCheckInDate!
              : record.date;
          final parsedDate = DateTime.parse(rawDate);
          baseDate = DateTime(parsedDate.year, parsedDate.month, parsedDate.day);
        } catch (_) {
          baseDate = DateTime(now.year, now.month, now.day);
        }
        final timeParts = checkInTime.split(':');
        if (timeParts.length >= 2) {
          final hour = int.tryParse(timeParts[0]) ?? 0;
          final minute = int.tryParse(timeParts[1]) ?? 0;
          checkIn = DateTime(baseDate.year, baseDate.month, baseDate.day, hour, minute);
          
          // Handle overnight shift only for early morning + late check-in time
          // Avoid false 23h duration when device/server time slightly out of sync
          final nowTime = now.hour * 60 + now.minute;
          final checkInTimeMinutes = hour * 60 + minute;

          final isEarlyMorning = nowTime < 360; // before 06:00
          final isLateEveningCheckIn = checkInTimeMinutes > 720; // after 12:00
          if (isEarlyMorning && isLateEveningCheckIn) {
            checkIn = checkIn.subtract(const Duration(days: 1));
            debugPrint('[PersistentNotification] Overnight shift: early morning + late check-in, using yesterday date');
          }
        } else {
          return 'Unknown';
        }
      } else {
        return 'Unknown';
      }

      final now = DateTime.now();
      final difference = now.difference(checkIn);
      
      // Handle negative duration (shouldn't happen after fix, but just in case)
      if (difference.isNegative) {
        debugPrint('[PersistentNotification] ⚠️ Negative duration detected, fixing...');
        // Try with yesterday date
        final checkInYesterday = checkIn.subtract(const Duration(days: 1));
        final diffFixed = now.difference(checkInYesterday);
        if (diffFixed.isNegative) {
          return '0m'; // Still negative, return 0
        }
        final hours = diffFixed.inHours;
        final minutes = diffFixed.inMinutes.remainder(60);
        if (hours > 0) {
          return '${hours}j ${minutes}m';
        } else {
          return '${minutes}m';
        }
      }

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

  /// Start periodic updates for notification (every 5 minutes to update duration)
  static Timer? _updateTimer;
  static AttendanceRecord? _currentRecord; // Store current record for periodic updates
  
  static void startPeriodicUpdates(AttendanceRecord todayRecord) {
    stopPeriodicUpdates(); // Stop any existing timer
    _currentRecord = todayRecord; // Store current record

    _updateTimer = Timer.periodic(_updateInterval, (_) {
      // Reload latest attendance data if available, otherwise use stored record
      if (_currentRecord != null) {
        updateCheckInNotification(_currentRecord!, shift: _currentShift);
      }
    });

    debugPrint('[PersistentNotification] Periodic updates started (every ${_updateInterval.inMinutes} minutes)');
  }
  
  /// Update the stored record for periodic updates (called when attendance changes)
  static void updateStoredRecord(AttendanceRecord todayRecord, {DailyShift? shift}) {
    _currentRecord = todayRecord;
    if (shift != null) {
      _currentShift = shift;
    }
  }

  /// Stop periodic updates
  static void stopPeriodicUpdates() {
    _updateTimer?.cancel();
    _updateTimer = null;
    debugPrint('[PersistentNotification] Periodic updates stopped');
  }

  static DateTime? _parseRecordDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) {
      return null;
    }
    try {
      return DateTime.parse(dateString);
    } catch (_) {
      return null;
    }
  }

  static DateTime? _parseCheckInDateTime(AttendanceRecord record) {
    final raw = record.checkIn;
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      if (raw.contains('T') || raw.contains('-')) {
        return DateTime.parse(raw);
      }
      final recordDate = _parseRecordDate(record.originalCheckInDate) ??
          _parseRecordDate(record.date) ??
          DateTime.now();
      final parts = raw.split(':');
      if (parts.length >= 2) {
        final hour = int.tryParse(parts[0]) ?? 0;
        final minute = int.tryParse(parts[1]) ?? 0;
        return DateTime(recordDate.year, recordDate.month, recordDate.day, hour, minute);
      }
    } catch (_) {}
    return null;
  }

  static int? _parseTimeToMinutes(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final parts = raw.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return hour * 60 + minute;
  }

  static String? _buildShiftLabel(DailyShift? shift) {
    if (shift == null) return null;
    final name = shift.name.isNotEmpty ? shift.name : 'Shift';
    final code = shift.code.isNotEmpty ? shift.code : '';
    final timeLabel = '${shift.startTime}-${shift.endTime}';
    if (code.isNotEmpty) {
      return '$code - $name ($timeLabel)';
    }
    return '$name ($timeLabel)';
  }

  static String? _buildShiftCheckoutLabel(
    AttendanceRecord record,
    DailyShift? shift,
  ) {
    if (shift == null) return null;
    final startMinutes = _parseTimeToMinutes(shift.startTime);
    final endMinutes = _parseTimeToMinutes(shift.endTime);
    if (startMinutes == null || endMinutes == null) {
      return shift.endTime;
    }
    final overnight = endMinutes <= startMinutes;
    if (overnight) {
      return '${shift.endTime} (besok)';
    }
    return shift.endTime;
  }

  static DateTime? _buildShiftEndDateTime(
    AttendanceRecord record,
    DailyShift? shift,
  ) {
    if (shift == null) return null;
    final endMinutes = _parseTimeToMinutes(shift.endTime);
    if (endMinutes == null) return null;
    final baseDate = _parseRecordDate(record.originalCheckInDate) ??
        _parseRecordDate(record.date) ??
        _parseCheckInDateTime(record) ??
        DateTime.now();
    final endHour = endMinutes ~/ 60;
    final endMinute = endMinutes % 60;
    var endDate = DateTime(baseDate.year, baseDate.month, baseDate.day, endHour, endMinute);
    final startMinutes = _parseTimeToMinutes(shift.startTime);
    if (startMinutes != null && endMinutes <= startMinutes) {
      endDate = endDate.add(const Duration(days: 1));
    }
    return endDate;
  }

  static String? _buildCheckoutReminderLine(
    AttendanceRecord record,
    DailyShift? shift,
  ) {
    final endDate = _buildShiftEndDateTime(record, shift);
    if (endDate == null) return null;
    final diff = endDate.difference(DateTime.now());
    if (diff.inMinutes <= 0) {
      return 'Waktu checkout sudah tiba';
    }
    if (diff.inMinutes <= 60) {
      return 'Sisa ${diff.inMinutes} menit menuju checkout';
    }
    return null;
  }

  /// Show location alert notification
  static Future<void> showLocationAlert(String title, String body) async {
    if (!_isInitialized) {
      debugPrint('[PersistentNotification] ⚠️ Service not initialized, cannot show location alert');
      return;
    }

    try {
      const notificationDetails = NotificationDetails(
        android: AndroidNotificationDetails(
          'location_alerts', // Different channel for location alerts
          'Location Alerts',
          channelDescription: 'Notifikasi alert lokasi dan durasi stay',
          importance: Importance.high,
          priority: Priority.high,
          showWhen: true,
          enableVibration: true,
          playSound: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );

      await _notificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000, // Unique ID based on timestamp
        title,
        body,
        notificationDetails,
      );

      debugPrint('[PersistentNotification] 📱 Location alert shown: $title');
    } catch (e) {
      debugPrint('[PersistentNotification] ⚠️ Error showing location alert: $e');
    }
  }

  /// Clean up resources
  static void dispose() {
    stopPeriodicUpdates();
    debugPrint('[PersistentNotification] Service disposed');
  }
}
