import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart' as geolocator;
import '../config/api_config.dart';
import '../models/user_model.dart';
import '../services/persistent_notification_service.dart';
import 'api_service.dart';

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

  // Movement threshold - hanya kirim jika bergerak >= 10 meter
  static const double MOVEMENT_THRESHOLD_METERS = 10.0;

  // Area monitoring settings (loaded from server)
  AreaMonitoringSettings? _areaSettings;
  bool _isSettingsLoaded = false;

  // Default settings jika belum load dari server
  static const int DEFAULT_WARNING_MINUTES = 60;
  static const int DEFAULT_CRITICAL_MINUTES = 120;
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
    _lastSentPosition = null;

    // Kirim lokasi awal (lokasi check-in) - dapatkan GPS location yang sebenarnya
    await _trackAndSendLocation(user.id, checkInDate);

    // Mulai timer untuk tracking berkala
    _trackingTimer = Timer.periodic(
      Duration(seconds: _intervalSeconds),
      (_) => _trackAndSendLocation(user.id, checkInDate),
    );

    debugPrint('[RealtimeLocationService] ✓ Realtime tracking started');
  }

  /// Berhenti tracking lokasi (saat check-out)
  Future<void> stopRealtimeTracking() async {
    if (!_isTracking) return;

    debugPrint('[RealtimeLocationService] 🛑 Stopping realtime location tracking...');

    _trackingTimer?.cancel();
    _trackingTimer = null;
    _lastSentPosition = null;
    _isTracking = false;

    // Reset location tracking saat check-out
    resetLocationTracking();

    debugPrint('[RealtimeLocationService] ✓ Realtime tracking stopped');
  }

  /// Track dan kirim lokasi saat ini
  Future<void> _trackAndSendLocation(String userId, DateTime checkInDate) async {
    try {
      // Cek permission GPS
      debugPrint('[RealtimeLocationService] 🔍 Checking GPS permission...');
      final permission = await geolocator.Geolocator.checkPermission();
      debugPrint('[RealtimeLocationService] GPS permission status: $permission');

      if (permission != geolocator.LocationPermission.whileInUse &&
          permission != geolocator.LocationPermission.always) {
        debugPrint('[RealtimeLocationService] ⚠ No GPS permission, requesting permission...');
        final requestedPermission = await geolocator.Geolocator.requestPermission();
        debugPrint('[RealtimeLocationService] Requested permission result: $requestedPermission');

        if (requestedPermission != geolocator.LocationPermission.whileInUse &&
            requestedPermission != geolocator.LocationPermission.always) {
          debugPrint('[RealtimeLocationService] ❌ GPS permission denied, skipping location update');
          return;
        }
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

      // Track location duration untuk monitoring
      _trackLocationDuration(position.latitude, position.longitude);

      // Cek movement threshold
      if (_lastSentPosition != null) {
        final distance = geolocator.Geolocator.distanceBetween(
          _lastSentPosition!.latitude,
          _lastSentPosition!.longitude,
          position.latitude,
          position.longitude,
        );

        // Jika jarak < threshold, skip pengiriman
        if (distance < MOVEMENT_THRESHOLD_METERS) {
          debugPrint('[RealtimeLocationService] 📍 Position unchanged (~${distance.toStringAsFixed(1)}m < ${MOVEMENT_THRESHOLD_METERS}m), skipping...');
          return;
        }
      }

      // Get location duration info
      final locationInfo = _getLocationDurationInfo(position.latitude, position.longitude);

      // Kirim lokasi baru dengan location monitoring info
      await _sendLocationLog(
        userId: userId,
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

      // Restart timer dengan interval baru
      _trackingTimer?.cancel();
      _trackingTimer = Timer.periodic(
        Duration(seconds: _intervalSeconds),
        (_) => _trackAndSendLocation('', DateTime.now()), // User ID dan date akan disediakan saat start
      );
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

  /// Track durasi di lokasi tertentu untuk monitoring (simplified)
  void _trackLocationDuration(double latitude, double longitude) {
    // Buat location key berdasarkan koordinat (rounded untuk grouping)
    // Round to ~100 meter precision untuk grouping lokasi serupa
    int latRounded = (latitude * 10).round();
    int lngRounded = (longitude * 10).round();
    String locationKey = '${latRounded}_${lngRounded}';

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

    // Update durasi
    _locationDurationMinutes[locationKey] = minutesInLocation;

    // Gunakan settings dari server atau default
    int warningMinutes = _areaSettings?.warningMinutes ?? DEFAULT_WARNING_MINUTES;
    int criticalMinutes = _areaSettings?.criticalMinutes ?? DEFAULT_CRITICAL_MINUTES;
    bool monitoringEnabled = _areaSettings?.enabled ?? true;

    // Simplified alert logic - alert jika terlalu lama di satu lokasi
    if (monitoringEnabled && minutesInLocation >= criticalMinutes) {
      debugPrint('[RealtimeLocationService] 🚨 CRITICAL ALERT: User has been at same location for ${minutesInLocation} minutes!');
      debugPrint('[RealtimeLocationService] 📍 Location: $latitude, $longitude (key: $locationKey)');
      _showLocationAlert('CRITICAL', minutesInLocation, latitude, longitude);
    } else if (monitoringEnabled && minutesInLocation >= warningMinutes && minutesInLocation % 30 == 0) { // Alert setiap 30 menit
      debugPrint('[RealtimeLocationService] ⚠️ WARNING ALERT: User at same location for ${minutesInLocation} minutes');
      debugPrint('[RealtimeLocationService] 📍 Location: $latitude, $longitude (key: $locationKey)');
      _showLocationAlert('WARNING', minutesInLocation, latitude, longitude);
    }
  }

  /// Show local notification for location alerts
  void _showLocationAlert(String alertType, int minutes, double latitude, double longitude) {
    try {
      // Format coordinates untuk display
      String coords = '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}';

      // Create notification content
      String title = '$alertType Alert - Lokasi';
      String body = 'Anda telah di lokasi yang sama selama $minutes menit\nKoordinat: $coords';

      // For now, use debug print - will integrate with notification service later
      debugPrint('[RealtimeLocationService] 📱 ALERT NOTIFICATION: $title');
      debugPrint('[RealtimeLocationService] 📱 $body');

      // TODO: Integrate with flutter_local_notifications
      // PersistentNotificationService.showLocationAlert(title, body);

    } catch (e) {
      debugPrint('[RealtimeLocationService] ⚠️ Error showing location alert: $e');
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

  /// Reset location tracking (dipanggil saat check-out)
  void resetLocationTracking() {
    _locationEntryTimes.clear();
    _locationDurationMinutes.clear();
    debugPrint('[RealtimeLocationService] 🔄 Location tracking reset');
  }
}
