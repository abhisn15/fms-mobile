import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart' as geolocator;
import 'package:permission_handler/permission_handler.dart';
import '../config/api_config.dart';
import '../models/user_model.dart';
import '../services/persistent_notification_service.dart';
import 'api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Area monitoring settings
class AreaMonitoringSettings {
  final bool enabled;
  final int warningMinutes;
  final int criticalMinutes;

  AreaMonitoringSettings({
    required this.enabled,
    required this.warningMinutes,
    required this.criticalMinutes,
  });

  factory AreaMonitoringSettings.fromJson(Map<String, dynamic> json) {
    return AreaMonitoringSettings(
      enabled: json['enabled'] ?? true,
      warningMinutes: json['warningMinutes'] ?? 60,
      criticalMinutes: json['criticalMinutes'] ?? 120,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'warningMinutes': warningMinutes,
      'criticalMinutes': criticalMinutes,
    };
  }
}

class RealtimeLocationService {
  static const int DEFAULT_WARNING_MINUTES = 60;
  static const int DEFAULT_CRITICAL_MINUTES = 120;

  // Location tracking state
  bool _isTracking = false;
  Timer? _trackingTimer;
  int _intervalSeconds = 60;
  double _movementThreshold = 1.0; // meters

  // User and attendance info
  String? _currentUserId;
  DateTime? _currentCheckInDate;
  String? _currentAttendanceId;

  // Location duration tracking (simplified)
  Map<String, DateTime> _locationEntryTimes = {}; // Track kapan mulai di lokasi tertentu
  Map<String, int> _locationDurationMinutes = {}; // Track durasi per lokasi

  // Area monitoring settings
  AreaMonitoringSettings? _areaSettings;

  // Singleton pattern
  static final RealtimeLocationService _instance = RealtimeLocationService._internal();
  factory RealtimeLocationService() => _instance;
  RealtimeLocationService._internal();

  // Getters
  bool get isTracking => _isTracking;
  int get intervalSeconds => _intervalSeconds;
  double get movementThreshold => _movementThreshold;

  // Initialize area monitoring settings
  Future<void> loadAreaMonitoringSettings() async {
    try {
      final response = await ApiService().get('/api/ess/location-settings');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.data);
        _areaSettings = AreaMonitoringSettings.fromJson(data['data']);
        debugPrint('[RealtimeLocationService] Area monitoring settings loaded: warning=${_areaSettings!.warningMinutes}m, critical=${_areaSettings!.criticalMinutes}m');
      }
    } catch (e) {
      debugPrint('[RealtimeLocationService] Failed to load area settings: $e');
      // Use defaults
      _areaSettings = AreaMonitoringSettings(
        enabled: true,
        warningMinutes: DEFAULT_WARNING_MINUTES,
        criticalMinutes: DEFAULT_CRITICAL_MINUTES,
      );
    }
  }

  // Start realtime location tracking
  Future<void> startRealtimeTracking({
    required User user,
    required String attendanceId,
    required DateTime checkInDate,
    int intervalSeconds = 60,
  }) async {
    if (_isTracking) {
      debugPrint('[RealtimeLocationService] Already tracking, stopping first...');
      await stopRealtimeTracking();
    }

    _currentUserId = user.id;
    _currentCheckInDate = checkInDate;
    _currentAttendanceId = attendanceId;
    _intervalSeconds = intervalSeconds;
    _movementThreshold = 1.0;

    // Load area monitoring settings
    await loadAreaMonitoringSettings();

    // Load existing location duration data
    await _loadLocationDurationData();

    // Start tracking
    debugPrint('[RealtimeLocationService] Starting realtime location tracking...');
    debugPrint('[RealtimeLocationService] User: ${user.name} (${user.id})');
    debugPrint('[RealtimeLocationService] Interval: $_intervalSeconds seconds');
    debugPrint('[RealtimeLocationService] Movement threshold: $_movementThreshold meters');
    debugPrint('[RealtimeLocationService] Area monitoring: ${_areaSettings?.enabled ?? true}');

    _isTracking = true;
    await _startLocationTracking();
  }

  // Stop realtime location tracking
  Future<void> stopRealtimeTracking() async {
    debugPrint('[RealtimeLocationService] Stopping realtime location tracking...');

    _isTracking = false;
    _trackingTimer?.cancel();
    _trackingTimer = null;

    // Save final location duration data
    await _saveLocationDurationData();

    // Clear current session data
    _currentUserId = null;
    _currentCheckInDate = null;
    _currentAttendanceId = null;

    debugPrint('[RealtimeLocationService] Realtime tracking stopped');
  }

  // Internal method to start location tracking
  Future<void> _startLocationTracking() async {
    // Check permissions
    final permission = await geolocator.Geolocator.checkPermission();
    if (permission == geolocator.LocationPermission.denied ||
        permission == geolocator.LocationPermission.deniedForever) {
      debugPrint('[RealtimeLocationService] Location permission denied');
      return;
    }

    final serviceEnabled = await geolocator.Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('[RealtimeLocationService] Location service not enabled');
      return;
    }

    // Start timer for periodic location tracking
    debugPrint('[RealtimeLocationService] Starting location tracking timer with interval: $_intervalSeconds seconds');
    _trackingTimer = Timer.periodic(
      Duration(seconds: _intervalSeconds),
      (timer) => _trackAndSendLocation(),
    );

    debugPrint('[RealtimeLocationService] Location tracking timer started successfully');
  }

  // Track and send location
  Future<void> _trackAndSendLocation() async {
    if (!_isTracking || _currentUserId == null || _currentAttendanceId == null) {
      return;
    }

    try {
      debugPrint('[RealtimeLocationService] Getting current position...');

      final position = await geolocator.Geolocator.getCurrentPosition(
        desiredAccuracy: geolocator.LocationAccuracy.high,
      );

      // Track location duration for monitoring
      await _trackLocationDuration(position.latitude, position.longitude);

      // Check location alerts
      await _checkLocationAlerts(position.latitude, position.longitude);

      // Send location to server
      await _sendLocationToServer(position);

    } catch (e) {
      debugPrint('[RealtimeLocationService] Error getting location: $e');
    }
  }

  // Track durasi di lokasi tertentu untuk monitoring dengan logic yang diminta
  Future<void> _trackLocationDuration(double latitude, double longitude) async {
    DateTime now = DateTime.now();

    // Round to ~25 meter precision untuk grouping lokasi (sesuai permintaan user)
    int latRounded = (latitude * 40).round(); // 1/40 = ~25 meter precision
    int lngRounded = (longitude * 40).round();
    String locationKey = '${latRounded}_${lngRounded}';

    // Check jika user pindah lokasi >25 meter dari lokasi sebelumnya
    String? previousLocationKey = _locationEntryTimes.keys.isNotEmpty ? _locationEntryTimes.keys.last : null;
    bool locationChanged = false;

    if (previousLocationKey != null && previousLocationKey != locationKey) {
      // Hitung jarak antara lokasi sebelumnya dan sekarang
      try {
        List<String> prevParts = previousLocationKey.split('_');
        List<String> currParts = locationKey.split('_');

        if (prevParts.length == 2 && currParts.length == 2) {
          double prevLat = double.parse(prevParts[0]) / 40.0;
          double prevLng = double.parse(prevParts[1]) / 40.0;
          double currLat = double.parse(currParts[0]) / 40.0;
          double currLng = double.parse(currParts[1]) / 40.0;

          double distance = geolocator.Geolocator.distanceBetween(prevLat, prevLng, currLat, currLng);

          if (distance > 25.0) { // > 25 meter = lokasi berubah
            locationChanged = true;
            debugPrint('[RealtimeLocationService] Location changed >25m (distance: ${distance.toStringAsFixed(1)}m)');
          }
        }
      } catch (e) {
        debugPrint('[RealtimeLocationService] Error calculating distance: $e');
      }
    }

    // Jika lokasi berubah atau baru pertama kali
    if (locationChanged || !_locationEntryTimes.containsKey(locationKey)) {
      // Jika lokasi berubah dan durasi sebelumnya >= 3 menit, catat durasi tersebut
      if (locationChanged && previousLocationKey != null) {
        int prevDuration = _locationDurationMinutes[previousLocationKey] ?? 0;
        if (prevDuration >= 3) { // Minimal 3 menit untuk dicatat
          debugPrint('[RealtimeLocationService] ✅ Recorded stay duration: $prevDuration minutes at $previousLocationKey');
        } else if (prevDuration < 1) { // Jika < 1 menit, ganti koordinat
          debugPrint('[RealtimeLocationService] ⏭️ Stay < 1 minute at $previousLocationKey, switching coordinates');
        }
      }

      // Reset untuk lokasi baru
      _locationEntryTimes[locationKey] = now;
      _locationDurationMinutes[locationKey] = 0;
      debugPrint('[RealtimeLocationService] 📍 New location tracking started: $locationKey at $now');
      debugPrint('[RealtimeLocationService] 📍 Coordinates: $latitude, $longitude');
    }

    // Hitung durasi di lokasi saat ini
    DateTime entryTime = _locationEntryTimes[locationKey]!;
    Duration duration = now.difference(entryTime);
    int minutesInLocation = duration.inMinutes;

    // Update durasi dengan batas maksimal (8 jam untuk work scenarios)
    const int maxDurationMinutes = 8 * 60; // 8 hours
    if (minutesInLocation > maxDurationMinutes) {
      debugPrint('[RealtimeLocationService] Duration capped at $maxDurationMinutes minutes for $locationKey');
      minutesInLocation = maxDurationMinutes;
    }

    _locationDurationMinutes[locationKey] = minutesInLocation;

    // Debug log durasi saat ini
    if (minutesInLocation > 0) {
      debugPrint('[RealtimeLocationService] ⏱️ Current stay duration at $locationKey: $minutesInLocation minutes');
    }

    // Save to persistent storage periodically
    if (minutesInLocation > 0 && minutesInLocation % 5 == 0) {
      _saveLocationDurationData();
    }
  }

  // Check for location alerts (WARNING only - critical removed)
  Future<void> _checkLocationAlerts(double latitude, double longitude) async {
    // Buat location key
    int latRounded = (latitude * 50).round();
    int lngRounded = (longitude * 50).round();
    String locationKey = '${latRounded}_${lngRounded}';

    // Ambil durasi saat ini
    int minutesInLocation = _locationDurationMinutes[locationKey] ?? 0;

    // Gunakan settings dari server atau default
    int warningMinutes = _areaSettings?.warningMinutes ?? DEFAULT_WARNING_MINUTES;
    bool monitoringEnabled = _areaSettings?.enabled ?? true;

    if (monitoringEnabled) {
      // Check untuk warning alert (setiap kelipatan 30 menit) - Critical alert dihapus karena terlalu mengganggu
      if (minutesInLocation >= warningMinutes && minutesInLocation % 30 == 0) {
        debugPrint('[RealtimeLocationService] WARNING ALERT: User at same location for $minutesInLocation minutes');
        debugPrint('[RealtimeLocationService] Location: $latitude, $longitude (key: $locationKey)');
        await _showLocationAlert('WARNING', minutesInLocation, latitude, longitude);
      }
    }
  }

  // Send location to server
  Future<void> _sendLocationToServer(geolocator.Position position) async {
    try {
      final locationData = {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'speed': position.speed,
        'heading': position.heading,
        'timestamp': position.timestamp.toIso8601String(),
        'attendanceId': _currentAttendanceId,
        'locationInfo': _getLocationDurationInfo(position.latitude, position.longitude),
      };

      final response = await ApiService().post('/api/supervisor/attendance/realtime/log', data: locationData);

      if (response.statusCode == 200) {
        debugPrint('[RealtimeLocationService] Location sent successfully');
      } else if (response.statusCode == 403) {
        debugPrint('[RealtimeLocationService] Failed to send location: 403 - Session expired?');
      } else {
        debugPrint('[RealtimeLocationService] Failed to send location: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[RealtimeLocationService] Error sending location: $e');
    }
  }

  // Get location duration info untuk dikirim ke server dengan logic stay duration per koordinat
  Map<String, dynamic> _getLocationDurationInfo(double latitude, double longitude) {
    int latRounded = (latitude * 40).round(); // ~25 meter precision
    int lngRounded = (longitude * 40).round();
    String currentLocationKey = '${latRounded}_${lngRounded}';

    // Collect semua durasi stay yang >= 3 menit dari koordinat yang berbeda
    List<Map<String, dynamic>> stayDurations = [];
    int totalStayDuration = 0;

    _locationEntryTimes.forEach((locationKey, entryTime) {
      int duration = _locationDurationMinutes[locationKey] ?? 0;

      // Hanya catat durasi >= 3 menit (sesuai logic user)
      if (duration >= 3) {
        // Parse koordinat dari locationKey
        List<String> parts = locationKey.split('_');
        if (parts.length == 2) {
          double coordLat = double.parse(parts[0]) / 40.0;
          double coordLng = double.parse(parts[1]) / 40.0;

          stayDurations.add({
            'locationKey': locationKey,
            'latitude': coordLat,
            'longitude': coordLng,
            'durationMinutes': duration,
            'entryTime': entryTime.toIso8601String(),
            'isCurrentLocation': locationKey == currentLocationKey,
          });

          totalStayDuration += duration;
        }
      }
    });

    // Info untuk lokasi saat ini
    int currentDuration = _locationDurationMinutes[currentLocationKey] ?? 0;
    DateTime currentEntryTime = _locationEntryTimes[currentLocationKey] ?? DateTime.now();

    return {
      'currentLocation': {
        'locationKey': currentLocationKey,
        'latitude': latitude,
        'longitude': longitude,
        'durationMinutes': currentDuration,
        'entryTime': currentEntryTime.toIso8601String(),
      },
      'stayDurations': stayDurations, // Array durasi stay per koordinat (>= 3 menit)
      'totalStayDuration': totalStayDuration,
      'totalLocations': _locationEntryTimes.length,
      'recordedStays': stayDurations.length,
    };
  }

  // Load location duration data from persistent storage
  Future<void> _loadLocationDurationData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // CLEAR ALL OLD DATA to prevent unrealistic durations
      // This fixes the issue where durations accumulate to 2+ hours unrealistically
      debugPrint('[RealtimeLocationService] Clearing all old location duration data to prevent unrealistic durations');
      _locationEntryTimes.clear();
      _locationDurationMinutes.clear();

      // Clear from persistent storage too
      await prefs.remove('location_entry_times');
      await prefs.remove('location_duration_minutes');

      // Fresh start - duration tracking will begin anew
      debugPrint('[RealtimeLocationService] Location duration data cleared - fresh start');

    } catch (e) {
      debugPrint('[RealtimeLocationService] Error loading location duration data: $e');
    }
  }

  // Save location duration data to persistent storage
  Future<void> _saveLocationDurationData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Convert maps to JSON
      final entryTimesJson = jsonEncode(
        _locationEntryTimes.map((key, value) => MapEntry(key, value.toIso8601String()))
      );
      final durationJson = jsonEncode(_locationDurationMinutes);

      await prefs.setString('location_entry_times', entryTimesJson);
      await prefs.setString('location_duration_minutes', durationJson);

      debugPrint('[RealtimeLocationService] Saved ${_locationEntryTimes.length} location entries');
    } catch (e) {
      debugPrint('[RealtimeLocationService] Error saving location duration data: $e');
    }
  }

  // Sync pending location logs
  Future<void> syncPendingLocationLogs() async {
    debugPrint('[RealtimeLocationService] Sync pending location logs - no pending logs to sync');
    // For now, just log that there's nothing to sync
  }

  // Show local notification for location alerts
  Future<void> _showLocationAlert(String alertType, int minutes, double latitude, double longitude) async {
    try {
      // Format coordinates untuk display
      String coords = '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}';

      // Create notification content
      String title = '$alertType Alert - Lokasi';
      String body = 'Anda telah di lokasi yang sama selama $minutes menit\nKoordinat: $coords';

      // Show actual notification to user
      debugPrint('[RealtimeLocationService] ALERT NOTIFICATION: $title');
      debugPrint('[RealtimeLocationService] $body');

      // Integrate with notification service
      await PersistentNotificationService.showLocationAlert(title, body);

    } catch (e) {
      debugPrint('[RealtimeLocationService] Error showing location alert: $e');
    }
  }

  // Helper method untuk membuka app settings
  Future<void> openAppSettings() async {
    debugPrint('[RealtimeLocationService] Opening app settings...');
    try {
      await openAppSettings();
      debugPrint('[RealtimeLocationService] App settings opened');
    } catch (e) {
      debugPrint('[RealtimeLocationService] Failed to open app settings: $e');
    }
  }
}