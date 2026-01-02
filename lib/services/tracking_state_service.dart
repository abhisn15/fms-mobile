import 'package:shared_preferences/shared_preferences.dart';

class TrackingState {
  final String userId;
  final String attendanceId;
  final DateTime checkInDate;
  final int intervalSeconds;

  const TrackingState({
    required this.userId,
    required this.attendanceId,
    required this.checkInDate,
    required this.intervalSeconds,
  });
}

class TrackingStateService {
  static const String _trackingActiveKey = 'tracking_active';
  static const String _trackingUserIdKey = 'tracking_user_id';
  static const String _trackingAttendanceIdKey = 'tracking_attendance_id';
  static const String _trackingCheckInDateKey = 'tracking_check_in_date';
  static const String _trackingIntervalKey = 'tracking_interval_seconds';
  static const String _appForegroundKey = 'app_foreground';

  static Future<void> saveTrackingState(TrackingState state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_trackingActiveKey, true);
    await prefs.setString(_trackingUserIdKey, state.userId);
    await prefs.setString(_trackingAttendanceIdKey, state.attendanceId);
    await prefs.setString(_trackingCheckInDateKey, state.checkInDate.toIso8601String());
    await prefs.setInt(_trackingIntervalKey, state.intervalSeconds);
  }

  static Future<void> clearTrackingState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_trackingActiveKey, false);
    await prefs.remove(_trackingUserIdKey);
    await prefs.remove(_trackingAttendanceIdKey);
    await prefs.remove(_trackingCheckInDateKey);
    await prefs.remove(_trackingIntervalKey);
  }

  static Future<TrackingState?> getTrackingState() async {
    final prefs = await SharedPreferences.getInstance();
    final active = prefs.getBool(_trackingActiveKey) ?? false;
    if (!active) return null;

    final userId = prefs.getString(_trackingUserIdKey);
    final attendanceId = prefs.getString(_trackingAttendanceIdKey);
    final checkInDateRaw = prefs.getString(_trackingCheckInDateKey);
    if (userId == null || attendanceId == null || checkInDateRaw == null) {
      return null;
    }

    final checkInDate = DateTime.tryParse(checkInDateRaw);
    if (checkInDate == null) {
      return null;
    }

    final intervalSeconds = prefs.getInt(_trackingIntervalKey) ?? 10;
    return TrackingState(
      userId: userId,
      attendanceId: attendanceId,
      checkInDate: checkInDate,
      intervalSeconds: intervalSeconds,
    );
  }

  static Future<void> setAppForeground(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_appForegroundKey, value);
  }

  static Future<bool> isAppForeground() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_appForegroundKey) ?? false;
  }
}
