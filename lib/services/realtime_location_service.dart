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
import 'dart:convert';

// Area monitoring settings
class AreaMonitoringSettings {
  final bool enabled;
  final int warningMinutes;
  final int criticalMinutes;
  final List<String> allowedAreas;
  final List<String> excludedAreas;

  AreaMonitoringSettings({
    required this.enabled,
    required this.warningMinutes,
    required this.criticalMinutes,
    required this.allowedAreas,
    required this.excludedAreas,
  });

  factory AreaMonitoringSettings.fromJson(Map<String, dynamic> json) {
    return AreaMonitoringSettings(
      enabled: json['enabled'] ?? true,
      warningMinutes: json['warningMinutes'] ?? 60,
      criticalMinutes: json['criticalMinutes'] ?? 120,
      allowedAreas: List<String>.from(json['allowedAreas'] ?? []),
      excludedAreas: List<String>.from(json['excludedAreas'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'warningMinutes': warningMinutes,
      'criticalMinutes': criticalMinutes,
      'allowedAreas': allowedAreas,
      'excludedAreas': excludedAreas,
    };
  }
}

// Realtime location service for tracking user location
class RealtimeLocationService {
  final ApiService _apiService = ApiService();
  Timer? _trackingTimer;
  geolocator.Position? _lastSentPosition;
  bool _isTracking = false;
  int _intervalSeconds = 300; // Default 5 menit (300 detik) untuk monitoring attendance
  String? _currentUserId; // Store current user ID for timer callbacks
  DateTime? _currentCheckInDate; // Store current check-in date for timer callbacks
  String? _currentAttendanceId; // Store current attendance ID for location logs

  // Movement threshold - hanya kirim jika bergerak >= 10 meter
  // Temporarily reduced for testing - increase back to 10.0 after testing
  static const double MOVEMENT_THRESHOLD_METERS = 1.0;

  // Area monitoring settings (loaded from server)
  AreaMonitoringSettings? _areaSettings;
  bool _isSettingsLoaded = false;

  // Default settings jika belum load dari server
  static const int DEFAULT_WARNING_MINUTES = 5;
  static const int DEFAULT_CRITICAL_MINUTES = 30;
  static const List<String> DEFAULT_ALLOWED_AREAS = [];

  // Simplified monitoring - track durasi per koordinat (rounded)
  Map<String, DateTime> _locationEntryTimes = {}; // Track kapan mulai di koordinat tertentu
  Map<String, int> _locationDurationMinutes = {}; // Track durasi per lokasi

  bool get isTracking => _isTracking;

  /// Load area monitoring settings dari server
  Future<void> loadAreaMonitoringSettings() async {
    try {
      // Gunakan endpoint ESS (bukan admin) karena mobile app bukan admin
      final response = await _apiService.get('/api/ess/area-monitoring');

      if (response.statusCode == 200 && response.data['success'] == true) {
        _areaSettings = AreaMonitoringSettings.fromJson(response.data['data']);
        _isSettingsLoaded = true;
        debugPrint('[RealtimeLocationService] ✅ Area monitoring settings loaded: warning=${_areaSettings!.warningMinutes}m, critical=${_areaSettings!.criticalMinutes}m');
        debugPrint('[RealtimeLocationService] 📋 Allowed areas: ${_areaSettings!.allowedAreas.join(", ")}');
      } else {
        // Fallback to default settings
        _areaSettings = AreaMonitoringSettings(
          enabled: true,
          warningMinutes: DEFAULT_WARNING_MINUTES,
          criticalMinutes: DEFAULT_CRITICAL_MINUTES,
          allowedAreas: DEFAULT_ALLOWED_AREAS,
          excludedAreas: [],
        );
        _isSettingsLoaded = true;
        debugPrint('[RealtimeLocationService] ⚠️ Using default area monitoring settings');
      }
    } catch (e) {
      // Fallback to default settings jika gagal load dari server
      _areaSettings = AreaMonitoringSettings(
        enabled: true,
        warningMinutes: DEFAULT_WARNING_MINUTES,
        criticalMinutes: DEFAULT_CRITICAL_MINUTES,
        allowedAreas: DEFAULT_ALLOWED_AREAS,
        excludedAreas: [],
      );
      _isSettingsLoaded = true;
      debugPrint('[RealtimeLocationService] ⚠️ Failed to load area settings, using defaults: $e');
    }
  }

  /// Mulai tracking lokasi secara realtime setelah check-in
  Future<void> startRealtimeTracking({
    required User user,
    required String attendanceId,
    required DateTime checkInDate,
    int intervalSeconds = 300, // Default 5 menit untuk monitoring
  }) async {
    if (_isTracking) {
      debugPrint('[RealtimeLocationService] ⚠ Already tracking, stopping first...');
      await stopRealtimeTracking();
    }

    // Load area monitoring settings jika belum di-load
    if (!_isSettingsLoaded) {
      await loadAreaMonitoringSettings();
    }

    debugPrint('[RealtimeLocationService] 🚀 Starting realtime location tracking...');
    debugPrint('[RealtimeLocationService] User: ${user.name} (${user.id})');
    debugPrint('[RealtimeLocationService] Interval: $intervalSeconds seconds');
    debugPrint('[RealtimeLocationService] Movement threshold: $MOVEMENT_THRESHOLD_METERS meters');
    debugPrint('[RealtimeLocationService] Area monitoring: ${_areaSettings?.enabled ?? false}');

    _isTracking = true;
    _intervalSeconds = intervalSeconds;
    _currentUserId = user.id; // Store user ID for timer callbacks
    _currentCheckInDate = checkInDate; // Store check-in date for timer callbacks
    _currentAttendanceId = attendanceId; // Store attendance ID
    _lastSentPosition = null;

    debugPrint('[RealtimeLocationService] 📝 Stored userId: $_currentUserId, attendanceId: $_currentAttendanceId');

    // Load existing location duration data if available
    await _loadLocationDurationData();

    // Load area monitoring settings
    await loadAreaMonitoringSettings();

    // Kirim lokasi awal (lokasi check-in) - dapatkan GPS location yang sebenarnya
    await _trackAndSendLocation(user.id, checkInDate);

      // Mulai timer untuk tracking berkala
    debugPrint('[RealtimeLocationService] 🕐 Starting location tracking timer with interval: $_intervalSeconds seconds');
    _trackingTimer = Timer.periodic(
      Duration(seconds: _intervalSeconds),
      (_) {
        debugPrint('[RealtimeLocationService] ⏰ Timer triggered - sending location update (interval: $_intervalSeconds seconds)');
        _trackAndSendLocation(user.id, checkInDate);
      },
    );
    debugPrint('[RealtimeLocationService] ✅ Location tracking timer started with interval: $_intervalSeconds seconds');
    debugPrint('[RealtimeLocationService] ✅ Location tracking timer started successfully');

    debugPrint('[RealtimeLocationService] ✓ Realtime tracking started');
  }

  /// Berhenti tracking lokasi (saat check-out)
  Future<void> stopRealtimeTracking() async {
    if (!_isTracking) return;

    debugPrint('[RealtimeLocationService] 🛑 Stopping realtime location tracking...');

    // Save location data before stopping
    await _saveLocationDurationData();

    _trackingTimer?.cancel();
    _trackingTimer = null;
    _lastSentPosition = null;
    _isTracking = false;

    debugPrint('[RealtimeLocationService] ✓ Realtime tracking stopped');
  }

  /// Track dan kirim lokasi saat ini
  Future<void> _trackAndSendLocation(String userId, DateTime checkInDate) async {
    debugPrint('[RealtimeLocationService] 🎯 _trackAndSendLocation called for user: $userId at ${DateTime.now()}');
    debugPrint('[RealtimeLocationService] 📊 Current location tracking state:');
    debugPrint('[RealtimeLocationService]   Entry times: $_locationEntryTimes');
    debugPrint('[RealtimeLocationService]   Duration minutes: $_locationDurationMinutes');
    try {
      // Cek permission GPS
      debugPrint('[RealtimeLocationService] 🔍 Checking GPS permission...');
      final permission = await geolocator.Geolocator.checkPermission();
      debugPrint('[RealtimeLocationService] GPS permission status: $permission');

      // Check if location service is enabled
      final locationServiceEnabled = await geolocator.Geolocator.isLocationServiceEnabled();
      debugPrint('[RealtimeLocationService] Location service enabled: $locationServiceEnabled');

      if (!locationServiceEnabled) {
        debugPrint('[RealtimeLocationService] ❌ Location service is disabled');
        return;
      }

      if (permission != geolocator.LocationPermission.whileInUse &&
          permission != geolocator.LocationPermission.always) {
        debugPrint('[RealtimeLocationService] ❌ GPS permission denied - should have been handled by PermissionStatusCard');
        throw Exception(
          'Izin lokasi belum diberikan. Silakan refresh dashboard dan berikan izin lokasi yang diperlukan.'
        );
      }

      // Log final permission status
      final finalPermission = await geolocator.Geolocator.checkPermission();
      debugPrint('[RealtimeLocationService] ✅ Final GPS permission: $finalPermission');

      // For Android 10+, check background permission status
      if (finalPermission == geolocator.LocationPermission.whileInUse) {
        debugPrint('[RealtimeLocationService] ⚠ WhileInUse permission only - background tracking limited');
        debugPrint('[RealtimeLocationService] 💡 Background tracking will work when app is in foreground only');
        // Don't throw error - allow tracking with current permission
        // PermissionStatusCard will show guidance for upgrading to background permission
      }

      // Cek apakah location service enabled
      debugPrint('[RealtimeLocationService] 🔍 Checking if location service is enabled...');
      final serviceEnabled = await geolocator.Geolocator.isLocationServiceEnabled();
      debugPrint('[RealtimeLocationService] Location service enabled: $serviceEnabled');

      if (!serviceEnabled) {
        debugPrint('[RealtimeLocationService] ⚠ Location service disabled, skipping location update');
        return;
      }

      // Ambil posisi saat ini
      debugPrint('[RealtimeLocationService] 📍 Getting current position...');
      final position = await geolocator.Geolocator.getCurrentPosition(
        desiredAccuracy: geolocator.LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      debugPrint('[RealtimeLocationService] ✅ Got position: ${position.latitude}, ${position.longitude} (accuracy: ${position.accuracy}m)');
      debugPrint('[RealtimeLocationService] 📊 Position details: speed=${position.speed}, heading=${position.heading}');

      // Track location duration untuk monitoring
      // Selalu update duration setiap kali dapat location
      _trackLocationDuration(position.latitude, position.longitude);

      // Selalu check untuk alert (terlepas dari movement threshold)
      await _checkLocationAlerts(position.latitude, position.longitude);

      // Cek movement threshold untuk pengiriman location
      if (_lastSentPosition != null) {
        final distance = geolocator.Geolocator.distanceBetween(
          _lastSentPosition!.latitude,
          _lastSentPosition!.longitude,
          position.latitude,
          position.longitude,
        );

        // Jika jarak < threshold, skip pengiriman tapi tetap track duration
        if (distance < MOVEMENT_THRESHOLD_METERS) {
          debugPrint('[RealtimeLocationService] 📍 Position unchanged (~${distance.toStringAsFixed(1)}m < ${MOVEMENT_THRESHOLD_METERS}m), skipping send but tracking duration...');
          return;
        }
      }

      // Get location duration info untuk dikirim
      final locationInfo = _getLocationDurationInfo(position.latitude, position.longitude);

      // Pastikan attendanceId tersedia
      if (_currentAttendanceId == null) {
        debugPrint('[RealtimeLocationService] ❌ ERROR: attendanceId is null, cannot send location');
        return;
      }

      debugPrint('[RealtimeLocationService] 📋 Sending location with attendanceId: $_currentAttendanceId');

      // Kirim lokasi baru dengan location monitoring info
      await _sendLocationLog(
        userId: userId,
        attendanceId: _currentAttendanceId!, // Send stored attendance ID
        latitude: position.latitude,
        longitude: position.longitude,
        date: checkInDate,
        accuracy: position.accuracy,
        speed: position.speed,
        heading: position.heading,
        locationInfo: locationInfo,
      );

      _lastSentPosition = position;

    } catch (e) {
      debugPrint('[RealtimeLocationService] ⚠ Error tracking location: $e');
      // Jangan throw error agar tracking terus berjalan
    }
  }

  /// Kirim log lokasi ke server
  Future<void> _sendLocationLog({
    required String userId,
    required String attendanceId,
    required double latitude,
    required double longitude,
    required DateTime date,
    double? accuracy,
    double? speed,
    double? heading,
    Map<String, dynamic>? locationInfo,
  }) async {
    try {
      final payload = {
        'userId': userId,
        'attendanceId': attendanceId,
        'date': date.toIso8601String().split('T')[0], // Format YYYY-MM-DD
        'latitude': latitude,
        'longitude': longitude,
        if (accuracy != null) 'accuracy': accuracy,
        if (speed != null && speed >= 0) 'speed': speed,
        if (heading != null && heading >= 0) 'heading': heading,
        // Location monitoring info
        if (locationInfo != null) 'locationInfo': locationInfo,
      };

      debugPrint('[RealtimeLocationService] 📤 Sending location: ${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}');

      final response = await _apiService.post(
        ApiConfig.realtimeLog,
        data: payload,
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['skipped'] == true) {
          debugPrint('[RealtimeLocationService] 📍 Location skipped: ${data['distanceMoved']?.toStringAsFixed(1) ?? 'N/A'}m < ${MOVEMENT_THRESHOLD_METERS}m threshold');
        } else {
          debugPrint('[RealtimeLocationService] ✅ Location sent successfully');
        }
      } else {
        debugPrint('[RealtimeLocationService] ⚠ Failed to send location: ${response.statusCode}');
      }

    } catch (e) {
      debugPrint('[RealtimeLocationService] ⚠ Error sending location log: $e');
      // Jangan throw error agar tracking terus berjalan
    }
  }

  /// Update interval tracking (dapat dipanggil saat user mengubah pengaturan)
  void updateInterval(int newIntervalSeconds) {
    if (_intervalSeconds != newIntervalSeconds && _isTracking) {
      debugPrint('[RealtimeLocationService] 🔄 Updating tracking interval: $_intervalSeconds → $newIntervalSeconds seconds');

      _intervalSeconds = newIntervalSeconds;

      // Restart timer dengan interval baru jika kita punya data yang diperlukan
      if (_currentUserId != null && _currentCheckInDate != null) {
        _trackingTimer?.cancel();
        _trackingTimer = Timer.periodic(
          Duration(seconds: _intervalSeconds),
          (_) {
            debugPrint('[RealtimeLocationService] ⏰ Timer triggered - sending location update (interval: $_intervalSeconds seconds)');
            _trackAndSendLocation(_currentUserId!, _currentCheckInDate!);
          },
        );
        debugPrint('[RealtimeLocationService] ✅ Location tracking timer restarted with new interval: $_intervalSeconds seconds');
      } else {
        debugPrint('[RealtimeLocationService] ⚠️ Cannot restart timer: missing stored user or check-in data');
      }
    }
  }

  /// Set app foreground status (untuk optimasi tracking)
  void setForegroundActive(bool isForeground) {
    // Untuk saat ini, tidak ada implementasi khusus
    // Bisa digunakan untuk optimasi di masa depan
    debugPrint('[RealtimeLocationService] 📱 Foreground status changed: $isForeground');
  }

  /// Sync pending location logs (dipanggil saat koneksi kembali tersedia)
  Future<void> syncPendingLocationLogs() async {
    // Untuk saat ini, semua location logs dikirim secara real-time
    // Tidak ada pending logs yang perlu disync
    debugPrint('[RealtimeLocationService] 🔄 Sync pending location logs - no pending logs to sync');
  }

  /// Check untuk location alerts berdasarkan durasi
  Future<void> _checkLocationAlerts(double latitude, double longitude) async {
    debugPrint('[RealtimeLocationService] 🔍 _checkLocationAlerts called for location: $latitude, $longitude');

    // Buat location key
    int latRounded = (latitude * 10).round();
    int lngRounded = (longitude * 10).round();
    String locationKey = '${latRounded}_${lngRounded}';

    debugPrint('[RealtimeLocationService] 🗝️ Location key: $locationKey');

    // Ambil durasi saat ini
    int minutesInLocation = _locationDurationMinutes[locationKey] ?? 0;

    debugPrint('[RealtimeLocationService] ⏱️ Current duration at $locationKey: $minutesInLocation minutes');
    debugPrint('[RealtimeLocationService] 📊 All location durations: $_locationDurationMinutes');

    // Gunakan settings dari server atau default
    int warningMinutes = _areaSettings?.warningMinutes ?? DEFAULT_WARNING_MINUTES;
    int criticalMinutes = _areaSettings?.criticalMinutes ?? DEFAULT_CRITICAL_MINUTES;
    bool monitoringEnabled = _areaSettings?.enabled ?? true;

    debugPrint('[RealtimeLocationService] ⚙️ Area monitoring settings:');
    debugPrint('[RealtimeLocationService]   Warning: $warningMinutes minutes');
    debugPrint('[RealtimeLocationService]   Critical: $criticalMinutes minutes');
    debugPrint('[RealtimeLocationService]   Enabled: $monitoringEnabled');

    if (monitoringEnabled) {
      // Check untuk critical alert
      if (minutesInLocation >= criticalMinutes) {
        debugPrint('[RealtimeLocationService] 🚨 CRITICAL ALERT: User has been at same location for ${minutesInLocation} minutes!');
        debugPrint('[RealtimeLocationService] 📍 Location: $latitude, $longitude (key: $locationKey)');
        await _showLocationAlert('CRITICAL', minutesInLocation, latitude, longitude);
      }
      // Check untuk warning alert (setiap kelipatan 30 menit)
      else if (minutesInLocation >= warningMinutes && minutesInLocation % 30 == 0) {
        debugPrint('[RealtimeLocationService] ⚠️ WARNING ALERT: User at same location for ${minutesInLocation} minutes');
        debugPrint('[RealtimeLocationService] 📍 Location: $latitude, $longitude (key: $locationKey)');
        await _showLocationAlert('WARNING', minutesInLocation, latitude, longitude);
      }
    }
  }

  /// Track durasi di lokasi tertentu untuk monitoring (simplified)
  void _trackLocationDuration(double latitude, double longitude) {
    debugPrint('[RealtimeLocationService] 📍 _trackLocationDuration called: $latitude, $longitude');

    // Buat location key berdasarkan koordinat (rounded untuk grouping)
    // Round to ~100 meter precision untuk grouping lokasi serupa
    int latRounded = (latitude * 10).round();
    int lngRounded = (longitude * 10).round();
    String locationKey = '${latRounded}_${lngRounded}';

    debugPrint('[RealtimeLocationService] 🗝️ Tracking duration for location key: $locationKey');

    DateTime now = DateTime.now();

    // Jika baru di lokasi ini atau lokasi berubah
    if (!_locationEntryTimes.containsKey(locationKey)) {
      _locationEntryTimes[locationKey] = now;
      _locationDurationMinutes[locationKey] = 0;
      debugPrint('[RealtimeLocationService] 📍 Started tracking location: $locationKey at $now');
      debugPrint('[RealtimeLocationService] 📍 Coordinates: $latitude, $longitude');

      // Clear old entries (> 24 jam) untuk memory management
      _cleanupOldLocationEntries(now);
    }

    // Hitung durasi di lokasi ini
    DateTime entryTime = _locationEntryTimes[locationKey]!;
    Duration duration = now.difference(entryTime);
    int minutesInLocation = duration.inMinutes;

    debugPrint('[RealtimeLocationService] ⏱️ Duration calculation:');
    debugPrint('[RealtimeLocationService]   Entry time: $entryTime');
    debugPrint('[RealtimeLocationService]   Current time: $now');
    debugPrint('[RealtimeLocationService]   Duration: ${duration.inMinutes} minutes');

    // Update durasi
    _locationDurationMinutes[locationKey] = minutesInLocation;
    debugPrint('[RealtimeLocationService] 💾 Updated duration for $locationKey: $minutesInLocation minutes');

    // Save to persistent storage periodically (every 5 minutes or when duration changes significantly)
    if (minutesInLocation > 0 && minutesInLocation % 5 == 0) {
      _saveLocationDurationData();
    }

    // Alert checking sekarang dilakukan di _checkLocationAlerts() yang dipanggil setiap kali mendapat location
  }

  /// Show local notification for location alerts
  Future<void> _showLocationAlert(String alertType, int minutes, double latitude, double longitude) async {
    try {
      // Format coordinates untuk display
      String coords = '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}';

      // Create notification content
      String title = '$alertType Alert - Lokasi';
      String body = 'Anda telah di lokasi yang sama selama $minutes menit\nKoordinat: $coords';

      // Show actual notification to user
      debugPrint('[RealtimeLocationService] 📱 ALERT NOTIFICATION: $title');
      debugPrint('[RealtimeLocationService] 📱 $body');

      // Integrate with notification service
      await PersistentNotificationService.showLocationAlert(title, body);

    } catch (e) {
      debugPrint('[RealtimeLocationService] ⚠️ Error showing location alert: $e');
    }
  }

  // Helper method untuk membuka app settings
  static Future<void> openAppSettings() async {
    debugPrint('[RealtimeLocationService] 🔧 Opening app settings...');
    try {
      await openAppSettings();
      debugPrint('[RealtimeLocationService] ✅ App settings opened');
    } catch (e) {
      debugPrint('[RealtimeLocationService] ❌ Failed to open app settings: $e');
    }
  }

  /// Cleanup old location entries untuk memory management
  void _cleanupOldLocationEntries(DateTime now) {
    List<String> toRemove = [];
    for (var entry in _locationEntryTimes.entries) {
      if (now.difference(entry.value).inHours > 24) {
        toRemove.add(entry.key);
      }
    }

    for (var key in toRemove) {
      _locationEntryTimes.remove(key);
      _locationDurationMinutes.remove(key);
    }

    if (toRemove.isNotEmpty) {
      debugPrint('[RealtimeLocationService] 🧹 Cleaned up ${toRemove.length} old location entries');
    }
  }

  /// Get location duration info untuk dikirim ke server
  Map<String, dynamic> _getLocationDurationInfo(double latitude, double longitude) {
    int latRounded = (latitude * 10).round();
    int lngRounded = (longitude * 10).round();
    String locationKey = '${latRounded}_${lngRounded}';

    int durationMinutes = _locationDurationMinutes[locationKey] ?? 0;
    DateTime entryTime = _locationEntryTimes[locationKey] ?? DateTime.now();

    return {
      'locationKey': locationKey,
      'entryTime': entryTime.toIso8601String(),
      'durationMinutes': durationMinutes,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  /// Get location monitoring summary untuk debugging
  Map<String, dynamic> getLocationMonitoringSummary() {
    Map<String, dynamic> summary = {
      'totalLocations': _locationEntryTimes.length,
      'locations': {},
      'alertsTriggered': 0,
    };

    DateTime now = DateTime.now();
    for (var entry in _locationEntryTimes.entries) {
      String locationKey = entry.key;
      DateTime entryTime = entry.value;
      Duration duration = now.difference(entryTime);
      int durationMinutes = _locationDurationMinutes[locationKey] ?? 0;

      summary['locations'][locationKey] = {
        'entryTime': entryTime.toIso8601String(),
        'durationMinutes': durationMinutes,
        'currentDuration': duration.inMinutes,
      };

      // Count potential alerts
      int warningMinutes = _areaSettings?.warningMinutes ?? DEFAULT_WARNING_MINUTES;
      if (duration.inMinutes >= warningMinutes) {
        summary['alertsTriggered'] = (summary['alertsTriggered'] as int) + 1;
      }
    }

    return summary;
  }

  /// Save location duration data to persistent storage
  Future<void> _saveLocationDurationData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Convert entry times to ISO string format for JSON storage
      Map<String, String> entryTimesData = {};
      _locationEntryTimes.forEach((key, value) {
        entryTimesData[key] = value.toIso8601String();
      });

      // Save data as JSON strings
      await prefs.setString('location_entry_times', jsonEncode(entryTimesData));
      await prefs.setString('location_duration_minutes', jsonEncode(_locationDurationMinutes));
      await prefs.setString('location_last_saved', DateTime.now().toIso8601String());

      debugPrint('[RealtimeLocationService] 💾 Location duration data saved to persistent storage');
    } catch (e) {
      debugPrint('[RealtimeLocationService] ❌ Failed to save location duration data: $e');
    }
  }

  /// Load location duration data from persistent storage
  Future<void> _loadLocationDurationData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load entry times
      String? entryTimesJson = prefs.getString('location_entry_times');
      if (entryTimesJson != null) {
        Map<String, dynamic> entryTimesData = jsonDecode(entryTimesJson);
        entryTimesData.forEach((key, value) {
          if (value is String) {
            try {
              _locationEntryTimes[key] = DateTime.parse(value);
            } catch (e) {
              debugPrint('[RealtimeLocationService] ❌ Failed to parse entry time for $key: $e');
            }
          }
        });
      }

      // Load duration minutes
      String? durationJson = prefs.getString('location_duration_minutes');
      if (durationJson != null) {
        Map<String, dynamic> durationData = jsonDecode(durationJson);
        durationData.forEach((key, value) {
          if (value is int) {
            _locationDurationMinutes[key] = value;
          }
        });
      }

      String? lastSaved = prefs.getString('location_last_saved');
      debugPrint('[RealtimeLocationService] 📂 Location duration data loaded from persistent storage (last saved: $lastSaved)');
      debugPrint('[RealtimeLocationService] 📊 Loaded ${_locationEntryTimes.length} location entries');

    } catch (e) {
      debugPrint('[RealtimeLocationService] ❌ Failed to load location duration data: $e');
      // Clear corrupted data
      await _clearLocationDurationData();
    }
  }

  /// Reset location tracking (dipanggil saat check-out)
  void resetLocationTracking() {
    _currentUserId = null;
    _currentCheckInDate = null;
    _currentAttendanceId = null;
    _locationEntryTimes.clear();
    _locationDurationMinutes.clear();

    // Clear persistent storage
    _clearLocationDurationData();

    debugPrint('[RealtimeLocationService] 🔄 Location tracking reset');
  }

  /// Clear location duration data from persistent storage
  Future<void> _clearLocationDurationData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('location_entry_times');
      await prefs.remove('location_duration_minutes');
      await prefs.remove('location_last_saved');
      debugPrint('[RealtimeLocationService] 🗑️ Location duration data cleared from persistent storage');
    } catch (e) {
      debugPrint('[RealtimeLocationService] ❌ Failed to clear location duration data: $e');
    }
  }
}
