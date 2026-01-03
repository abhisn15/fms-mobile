import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geolocator;
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../config/api_config.dart';
import '../models/user_model.dart';
import '../services/persistent_notification_service.dart';
import '../services/offline_storage_service.dart';
import 'api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

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
  bool _isSendingLocation = false; // Prevent concurrent location sending
  Timer? _trackingTimer;
  DateTime? _lastLocationSendTime; // Track last send time to prevent spam
  geolocator.Position? _lastSentPosition; // Last sent position for movement detection
  int _intervalSeconds = 60;
  double _movementThreshold = 1.0; // meters
  double _stayRadiusMeters =
      25.0; // Radius untuk menentukan "stay" di lokasi yang sama

  // User and attendance info
  String? _currentUserId;
  DateTime? _currentCheckInDate;
  String? _currentAttendanceId;

  // Location duration tracking (simplified)
  Map<String, DateTime> _locationEntryTimes =
      {}; // Track kapan mulai di lokasi tertentu
  Map<String, int> _locationDurationMinutes =
      {}; // Track durasi real-time per lokasi

  // Final stay durations (recorded when location changes)
  Map<String, int> _finalStayDurations =
      {}; // Store final stay durations when location changes

  // Area monitoring settings
  AreaMonitoringSettings? _areaSettings;

  // Services
  final OfflineStorageService _offlineStorage = OfflineStorageService();
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  // GPS mandatory check - returns true if GPS is enabled, false if disabled
  Future<bool> _checkGPSMandatory() async {
    final serviceEnabled =
        await geolocator.Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('[RealtimeLocationService] 🚨 GPS MANDATORY: GPS is disabled');

      // Open location settings to encourage user to enable GPS
      await geolocator.Geolocator.openLocationSettings();

      // Wait a bit for user to enable GPS
      await Future.delayed(const Duration(seconds: 2));

      // Check again
      final recheckService =
          await geolocator.Geolocator.isLocationServiceEnabled();
      return recheckService;
    }
    return true;
  }

  // Singleton pattern
  static final RealtimeLocationService _instance =
      RealtimeLocationService._internal();
  factory RealtimeLocationService() => _instance;
  RealtimeLocationService._internal();

  // Manual sync offline location logs
  Future<void> syncOfflineData() async {
    debugPrint(
      '[RealtimeLocationService] 🔄 Manual sync of offline location logs requested',
    );
    await _syncOfflineLocationLogs();
  }

  // Record final duration for the last sent location before moving to new location
  Future<void> _recordFinalDurationForLastLocation() async {
    if (_lastSentPosition == null) return;

    final now = DateTime.now();

    // Calculate location key for last sent position
    int latRounded = (_lastSentPosition!.latitude * 200).round();
    int lngRounded = (_lastSentPosition!.longitude * 200).round();
    String lastLocationKey = '${latRounded}_${lngRounded}';

    // If we have entry time for this location, calculate final duration
    if (_locationEntryTimes.containsKey(lastLocationKey)) {
      DateTime entryTime = _locationEntryTimes[lastLocationKey]!;
      Duration finalDuration = now.difference(entryTime);
      int finalMinutes = finalDuration.inMinutes;

      // Record as final stay duration
      _finalStayDurations[lastLocationKey] = finalMinutes;

      debugPrint(
        '[RealtimeLocationService] 🏁 FINAL DURATION RECORDED: $lastLocationKey = $finalMinutes minutes (${finalDuration.inSeconds} seconds)',
      );

      if (finalMinutes >= 3) {
        debugPrint(
          '[RealtimeLocationService] ✅ Valid final stay: $finalMinutes minutes at $lastLocationKey',
        );
      }
    } else {
      debugPrint(
        '[RealtimeLocationService] ⚠️ No entry time found for last location: $lastLocationKey',
      );
    }
  }

  // DEBUG: Force record current location as final stay (for testing)
  void forceRecordCurrentStay() {
    if (_locationEntryTimes.isNotEmpty && _currentAttendanceId != null) {
      final now = DateTime.now();
      final currentKey = _locationEntryTimes.keys.last;

      if (_locationEntryTimes.containsKey(currentKey)) {
        final entryTime = _locationEntryTimes[currentKey]!;
        final duration = now.difference(entryTime);
        final minutes = duration.inMinutes;

        _finalStayDurations[currentKey] = minutes;

        debugPrint(
          '[RealtimeLocationService] 🔧 FORCED: Recorded stay at $currentKey = $minutes minutes',
        );
        debugPrint(
          '[RealtimeLocationService] 📈 Total final stays after force: ${_finalStayDurations.length}',
        );

        // Force send updated data to server immediately (gunakan position terakhir yang tersimpan)
        // Note: _lastPosition tidak ada, jadi skip force send untuk sekarang
        debugPrint(
          '[RealtimeLocationService] ℹ️ Force send skipped - position data not available',
        );
      }
    }
  }

  // Get pending offline logs count
  Future<int> getPendingOfflineLogsCount() async {
    final pendingLogs = await _offlineStorage.getPendingLocationLogs();
    return pendingLogs.length;
  }

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
        debugPrint(
          '[RealtimeLocationService] Area monitoring settings loaded: warning=${_areaSettings!.warningMinutes}m, critical=${_areaSettings!.criticalMinutes}m',
        );
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

  // Auto-detect low-end device based on device model and Android version
  Future<bool> _isLowEndDevice() async {
    try {
      final deviceInfo = DeviceInfoPlugin();

      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        final model = androidInfo.model?.toLowerCase() ?? '';
        final brand = androidInfo.brand?.toLowerCase() ?? '';

        // Known low-end devices that need optimization
        final lowEndModels = [
          'redmi 5', 'redmi 5a', 'redmi 4', 'redmi 4a', 'redmi 3',
          'xiaomi mi a1', 'xiaomi mi a2', 'xiaomi redmi',
          'samsung j2', 'samsung j4', 'samsung j5', 'samsung j7',
          'oppo a3', 'oppo a5', 'oppo a7',
          'vivo y5', 'vivo y7', 'vivo y9'
        ];

        final isKnownLowEnd = lowEndModels.any((modelName) =>
          model.contains(modelName) || brand.contains(modelName.split(' ')[0]));

        // Check Android version (Android 7 and below typically low-end)
        final androidVersion = androidInfo.version.sdkInt ?? 0;
        final isOldAndroid = androidVersion <= 25; // Android 7.1 and below

        final result = isKnownLowEnd || isOldAndroid;
        debugPrint('[RealtimeLocationService] 📱 Device: ${androidInfo.brand} ${androidInfo.model} (Android ${androidInfo.version.release}) - Low-end: $result');
        return result;
      }

      return false; // iOS devices generally have better performance
    } catch (e) {
      debugPrint('[RealtimeLocationService] ⚠️ Could not detect device type: $e');
      return false; // Default to not low-end if detection fails
    }
  }

  // Start realtime location tracking with device optimization
  Future<void> startRealtimeTracking({
    required User user,
    required String attendanceId,
    required DateTime checkInDate,
    int intervalSeconds = 60,
    bool optimizeForLowEndDevice = false, // Auto-detect low-end device
  }) async {
    if (_isTracking) {
      debugPrint(
        '[RealtimeLocationService] Already tracking, stopping first...',
      );
      await stopRealtimeTracking();
    }

    _currentUserId = user.id;
    _currentCheckInDate = checkInDate;
    _currentAttendanceId = attendanceId;

    // Auto-detect or use manual flag for low-end device optimization
    final isLowEnd = optimizeForLowEndDevice || await _isLowEndDevice();

    // Optimize for low-end devices (like Redmi 5A)
    if (isLowEnd) {
      _intervalSeconds = (intervalSeconds * 3)
          .round(); // Longer interval (3x) for battery saving on low-end devices
      _movementThreshold = 10.0; // Larger movement threshold to reduce GPS processing
      debugPrint(
        '[RealtimeLocationService] 📱 Optimized for low-end device: interval=${_intervalSeconds}s, threshold=${_movementThreshold}m',
      );
      debugPrint(
        '[RealtimeLocationService] 🔋 Low-end device optimizations active - reduced battery/network usage',
      );
    } else {
      _intervalSeconds = intervalSeconds;
      _movementThreshold = 1.0; // Default smaller threshold for better accuracy
      _movementThreshold = 1.0;
    }

    // Load area monitoring settings
    await loadAreaMonitoringSettings();

    // Load existing location duration data
    await _loadLocationDurationData();

    // Start tracking
    debugPrint(
      '[RealtimeLocationService] Starting realtime location tracking...',
    );
    debugPrint('[RealtimeLocationService] User: ${user.name} (${user.id})');
    debugPrint('[RealtimeLocationService] Interval: $_intervalSeconds seconds');
    debugPrint(
      '[RealtimeLocationService] Movement threshold: $_movementThreshold meters',
    );
    debugPrint(
      '[RealtimeLocationService] Area monitoring: ${_areaSettings?.enabled ?? true}',
    );

    _isTracking = true;

    // Listen for connectivity changes to sync offline data when online
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      final result = results.isNotEmpty
          ? results.first
          : ConnectivityResult.none;
      if (result != ConnectivityResult.none) {
        debugPrint(
          '[RealtimeLocationService] 📡 Connectivity restored - syncing offline data',
        );
        _syncOfflineLocationLogs();
      }
    });

    await _startLocationTracking();
  }

  // Stop realtime location tracking
  Future<void> stopRealtimeTracking() async {
    debugPrint(
      '[RealtimeLocationService] Stopping realtime location tracking...',
    );

    _isTracking = false;
    _isSendingLocation = false; // Reset sending flag
    _lastLocationSendTime = null; // Reset last send time
    _lastSentPosition = null; // Reset last sent position
    _trackingTimer?.cancel();
    _trackingTimer = null;
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;

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

    // MANDATORY GPS CHECK: GPS harus aktif untuk location tracking
    final gpsEnabled = await _checkGPSMandatory();
    if (!gpsEnabled) {
      debugPrint(
        '[RealtimeLocationService] 🚨 GPS MANDATORY: GPS check failed - cannot start location tracking',
      );
      return;
    }

    // Start timer for periodic location tracking
    debugPrint(
      '[RealtimeLocationService] Starting location tracking timer with interval: $_intervalSeconds seconds',
    );
    _trackingTimer = Timer.periodic(
      Duration(seconds: _intervalSeconds),
      (timer) => _trackAndSendLocation(),
    );

    debugPrint(
      '[RealtimeLocationService] Location tracking timer started successfully',
    );
  }

  // Track and send location
  Future<void> _trackAndSendLocation() async {
    if (!_isTracking ||
        _currentUserId == null ||
        _currentAttendanceId == null) {
      return;
    }

    // Prevent concurrent location sending
    if (_isSendingLocation) {
      debugPrint(
        '[RealtimeLocationService] Location sending already in progress, skipping...',
      );
      return;
    }

    // Prevent spamming - ensure minimum interval between sends (30 seconds minimum)
    final now = DateTime.now();
    if (_lastLocationSendTime != null) {
      final timeSinceLastSend = now.difference(_lastLocationSendTime!);
      if (timeSinceLastSend.inSeconds < 30) {
        debugPrint(
          '[RealtimeLocationService] ⏳ Too soon since last send (${timeSinceLastSend.inSeconds}s ago < 30s), skipping...',
        );
        return;
      }
    }

    debugPrint(
      '[RealtimeLocationService] 🚀 Starting location tracking cycle at ${now.toIso8601String().split('T')[1].split('.')[0]}',
    );
    _isSendingLocation = true;
    _lastLocationSendTime = now;

    try {
      debugPrint('[RealtimeLocationService] Getting current position...');

      final position = await geolocator.Geolocator.getCurrentPosition(
        desiredAccuracy: geolocator.LocationAccuracy.high,
      );

      // Track location duration for monitoring
      await _trackLocationDuration(position.latitude, position.longitude);

      // Check location alerts
      await _checkLocationAlerts(position.latitude, position.longitude);

      // Only send to server if position has changed significantly (>25m) from last sent position
      bool shouldSendToServer = true;

      if (_lastSentPosition != null) {
        double distanceFromLastSent = geolocator.Geolocator.distanceBetween(
          _lastSentPosition!.latitude,
          _lastSentPosition!.longitude,
          position.latitude,
          position.longitude,
        );

        if (distanceFromLastSent <= _stayRadiusMeters) {
          // Still within 25m radius from last sent position, skip sending
          shouldSendToServer = false;
          debugPrint(
            '[RealtimeLocationService] 📍 Still within ${_stayRadiusMeters}m of last sent position (${distanceFromLastSent.toStringAsFixed(1)}m), skipping server send',
          );
        } else {
          debugPrint(
            '[RealtimeLocationService] 📤 Position changed >${_stayRadiusMeters}m (${distanceFromLastSent.toStringAsFixed(1)}m), sending to server',
          );
        }
      } else {
        debugPrint(
          '[RealtimeLocationService] 📤 First position, sending to server',
        );
      }

      if (shouldSendToServer) {
        // Before sending, record final duration for previous location if any
        if (_lastSentPosition != null) {
          // Calculate duration spent at previous location before moving
          await _recordFinalDurationForLastLocation();
        }

        // Send location to server
        await _sendLocationToServer(position);
        // Update last sent position
        _lastSentPosition = position;

        debugPrint(
          '[RealtimeLocationService] 📍 Updated last sent position: ${position.latitude}, ${position.longitude}',
        );
      }
    } catch (e) {
      debugPrint('[RealtimeLocationService] Error getting location: $e');
    } finally {
      _isSendingLocation = false;
    }
  }

  // Track durasi di lokasi tertentu untuk monitoring dengan logic yang diminta
  Future<void> _trackLocationDuration(double latitude, double longitude) async {
    final now = DateTime.now();

    // Round to stay radius precision untuk grouping lokasi (sesuai permintaan user)
    // Gunakan precision 200 (~5m) agar lebih sensitif terhadap perubahan lokasi
    int latRounded = (latitude * 200)
        .round(); // 1/200 = ~5 meter precision (lebih sensitif)
    int lngRounded = (longitude * 200).round();
    String locationKey = '${latRounded}_${lngRounded}';

    // Check jika user pindah lokasi > radius meter dari lokasi sebelumnya
    String? previousLocationKey = _locationEntryTimes.keys.isNotEmpty
        ? _locationEntryTimes.keys.last
        : null;
    bool locationChanged = false;
    double actualDistance = 0.0;

    if (previousLocationKey != null) {
      // Selalu hitung jarak aktual dari lokasi sebelumnya
      try {
        List<String> prevParts = previousLocationKey.split('_');
        if (prevParts.length == 2) {
          double prevLat =
              double.parse(prevParts[0]) /
              200.0; // Sesuai precision yang digunakan
          double prevLng = double.parse(prevParts[1]) / 200.0;
          double currLat = latitude;
          double currLng = longitude;

          actualDistance = geolocator.Geolocator.distanceBetween(
            prevLat,
            prevLng,
            currLat,
            currLng,
          );

          debugPrint(
            '[RealtimeLocationService] 📏 Distance from previous location: ${actualDistance.toStringAsFixed(1)}m',
          );

          if (actualDistance > _stayRadiusMeters) {
            // > radius meter = lokasi berubah
            locationChanged = true;
            debugPrint(
              '[RealtimeLocationService] 🎯 LOCATION CHANGED >${_stayRadiusMeters}m (distance: ${actualDistance.toStringAsFixed(1)}m)',
            );
          } else {
            debugPrint(
              '[RealtimeLocationService] ✅ Same location (distance: ${actualDistance.toStringAsFixed(1)}m <= ${_stayRadiusMeters}m)',
            );
          }
        }
      } catch (e) {
        debugPrint('[RealtimeLocationService] Error calculating distance: $e');
      }
    } else {
      debugPrint('[RealtimeLocationService] 📍 First location tracking');
    }

    debugPrint(
      '[RealtimeLocationService] 🔍 Checking location: $locationKey ($latitude, $longitude)',
    );
    debugPrint(
      '[RealtimeLocationService] 📊 Previous key: $previousLocationKey, Current keys: ${_locationEntryTimes.keys.toList()}',
    );

    // Jika lokasi berubah atau baru pertama kali
    if (locationChanged || !_locationEntryTimes.containsKey(locationKey)) {
      debugPrint(
        '[RealtimeLocationService] 🎯 Location change detected! Changed: $locationChanged, New location: ${!_locationEntryTimes.containsKey(locationKey)}',
      );

      // Jika lokasi berubah, hitung durasi stay di lokasi SEBELUMNYA dan simpan sebagai FINAL
      if (locationChanged && previousLocationKey != null) {
        // Hitung durasi stay yang SEBENARNYA di lokasi sebelumnya (dari mulai masuk sampai sekarang)
        DateTime prevEntryTime = _locationEntryTimes[previousLocationKey]!;
        Duration prevStayDuration = now.difference(prevEntryTime);
        int prevStayMinutes = prevStayDuration.inMinutes;

        // Simpan sebagai FINAL stay duration (durasi di lokasi sebelumnya)
        _finalStayDurations[previousLocationKey] = prevStayMinutes;

        debugPrint(
          '[RealtimeLocationService] 📊 FINAL STAY RECORDED: $previousLocationKey = $prevStayMinutes minutes (${prevStayDuration.inSeconds} seconds)',
        );
        debugPrint(
          '[RealtimeLocationService] 📈 Total final stays: ${_finalStayDurations.length}',
        );

        if (prevStayMinutes >= 3) {
          debugPrint(
            '[RealtimeLocationService] ✅ Recorded stay duration: $prevStayMinutes minutes at $previousLocationKey',
          );
        }
      } else {
        debugPrint(
          '[RealtimeLocationService] ℹ️ First location or returning to existing location',
        );
      }

      // Mulai tracking lokasi BARU - RESET TIMER dari 0
      _locationEntryTimes[locationKey] = now;
      _locationDurationMinutes[locationKey] =
          0; // Reset durasi untuk koordinat baru

      debugPrint(
        '[RealtimeLocationService] 🆕 ENTERED NEW LOCATION: $locationKey at ${now.toIso8601String().split('T')[1].split('.')[0]}',
      );
      debugPrint(
        '[RealtimeLocationService] 📍 Coordinates: $latitude, $longitude (timer reset to 0)',
      );
    } else {
      debugPrint(
        '[RealtimeLocationService] ✅ Staying in same location: $locationKey',
      );
    }

    // Hitung durasi stay di koordinat SAAT INI (dari mulai masuk koordinat ini)
    DateTime entryTime = _locationEntryTimes[locationKey]!;
    Duration currentStayDuration = now.difference(entryTime);
    int currentStayMinutes = currentStayDuration.inMinutes;

    // Cap at reasonable maximum (8 hours)
    const int maxDurationMinutes = 8 * 60;
    if (currentStayMinutes > maxDurationMinutes) {
      currentStayMinutes = maxDurationMinutes;
    }

    // Update durasi real-time untuk koordinat saat ini
    _locationDurationMinutes[locationKey] = currentStayMinutes;

    // Debug log durasi di koordinat saat ini
    if (currentStayMinutes > 0 && currentStayMinutes % 1 == 0) {
      // Log setiap menit
      debugPrint(
        '[RealtimeLocationService] ⏱️ Current stay at $locationKey: $currentStayMinutes minutes (since ${entryTime.toIso8601String().split('T')[1].split('.')[0]})',
      );
    }

    // Save to persistent storage periodically
    if (currentStayMinutes > 0 && currentStayMinutes % 5 == 0) {
      _saveLocationDurationData();
    }
  }

  // Check for location alerts (WARNING only - critical removed)
  Future<void> _checkLocationAlerts(double latitude, double longitude) async {
    final now = DateTime.now();

    // Buat location key
    int latRounded = (latitude * 50).round();
    int lngRounded = (longitude * 50).round();
    String locationKey = '${latRounded}_${lngRounded}';

    // Hitung durasi real-time untuk koordinat saat ini
    DateTime entryTime = _locationEntryTimes[locationKey] ?? now;
    int minutesInLocation = now.difference(entryTime).inMinutes;

    // Gunakan settings dari server atau default
    int warningMinutes =
        _areaSettings?.warningMinutes ?? DEFAULT_WARNING_MINUTES;
    bool monitoringEnabled = _areaSettings?.enabled ?? true;

    if (monitoringEnabled) {
      // Check untuk warning alert (setiap kelipatan 30 menit) - Critical alert dihapus karena terlalu mengganggu
      if (minutesInLocation >= warningMinutes && minutesInLocation % 30 == 0) {
        debugPrint(
          '[RealtimeLocationService] WARNING ALERT: User at same location for $minutesInLocation minutes',
        );
        debugPrint(
          '[RealtimeLocationService] Location: $latitude, $longitude (key: $locationKey)',
        );
        await _showLocationAlert(
          'WARNING',
          minutesInLocation,
          latitude,
          longitude,
        );
      }
    }
  }

  // Send location to server with offline handling
  Future<void> _sendLocationToServer(geolocator.Position position) async {
    try {
      // Check connectivity first
      final connectivityResult = await _connectivity.checkConnectivity();
      final isOnline = connectivityResult != ConnectivityResult.none;

      debugPrint(
        '[RealtimeLocationService] 📡 Connectivity check: $connectivityResult (online: $isOnline)',
      );

      if (!isOnline) {
        // Offline: Save to local storage
        debugPrint(
          '[RealtimeLocationService] 📴 Offline detected - saving location to local storage',
        );
        await _saveLocationOffline(position);
        return;
      }
      // Format date sesuai dengan yang diharapkan API (YYYY-MM-DD)
      final dateString =
          _currentCheckInDate?.toIso8601String().split('T')[0] ??
          DateTime.now().toIso8601String().split('T')[0];

      // Get location info for backward compatibility with web app
      final locationInfo = _getLocationDurationInfo(
        position.latitude,
        position.longitude,
      );

      final locationData = {
        'userId': _currentUserId, // ✅ Tambahkan userId
        'attendanceId': _currentAttendanceId, // ✅ AttendanceId
        'date': dateString, // ✅ Tambahkan date
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'speed': position.speed,
        'heading': position.heading,
        'locationInfo': locationInfo, // ✅ Data duration info
        // For backward compatibility - web app expects areaInfo.durationMinutes
        'areaInfo': {
          'currentLocation': locationInfo['currentLocation'],
          'stayDurations': locationInfo['stayDurations'],
          'totalStayDuration': locationInfo['totalStayDuration'],
          'totalLocations': locationInfo['totalLocations'],
          'recordedStays': locationInfo['recordedStays'],
          // Add durationMinutes for web app compatibility (use current real-time duration)
          'durationMinutes': locationInfo['currentLocation']['durationMinutes'],
        },
      };

      debugPrint('[RealtimeLocationService] 📤 Sending location data:');
      debugPrint('  - userId: $_currentUserId');
      debugPrint('  - attendanceId: $_currentAttendanceId');
      debugPrint('  - date: $dateString');
      debugPrint(
        '  - coordinates: ${position.latitude}, ${position.longitude}',
      );
      debugPrint('  - accuracy: ${position.accuracy}');
      debugPrint(
        '  - locationInfo keys: ${(locationData['locationInfo'] as Map<String, dynamic>)?.keys.length ?? 0}',
      );

      final response = await ApiService().post(
        '/api/supervisor/attendance/realtime/log',
        data: locationData,
      );

      debugPrint(
        '[RealtimeLocationService] 📡 API Response: ${response.statusCode}',
      );
      if (response.statusCode == 200) {
        debugPrint('[RealtimeLocationService] ✅ Location sent successfully');

        // Mark current location as "sent" - durasi akan dihitung dari sini untuk lokasi berikutnya
        // Location duration tracking akan continue, tapi data sudah dikirim ke server
      } else if (response.statusCode == 400) {
        debugPrint(
          '[RealtimeLocationService] ❌ Bad Request (400) - Data validation error',
        );
        debugPrint('  - Response: ${response.data}');
        // Jika 400, kemungkinan data yang dikirim tidak lengkap atau tidak valid
        debugPrint(
          '  - Check if userId, attendanceId, and date are properly set',
        );
        debugPrint('  - Current userId: $_currentUserId');
        debugPrint('  - Current attendanceId: $_currentAttendanceId');
        debugPrint('  - Current checkInDate: $_currentCheckInDate');
      } else if (response.statusCode == 403) {
        debugPrint(
          '[RealtimeLocationService] ❌ Forbidden (403) - Session expired or invalid user',
        );
        debugPrint('  - User may need to re-login');
      } else if (response.statusCode == 404) {
        debugPrint(
          '[RealtimeLocationService] ❌ Not Found (404) - Attendance record not found',
        );
        debugPrint('  - Attendance ID may be invalid: $_currentAttendanceId');
      } else if (response.statusCode == 409) {
        debugPrint(
          '[RealtimeLocationService] ❌ Conflict (409) - Attendance already checked out or not checked in',
        );
        debugPrint('  - Check attendance status for ID: $_currentAttendanceId');
      } else {
        debugPrint(
          '[RealtimeLocationService] ❌ Failed to send location: ${response.statusCode}',
        );
        debugPrint('  - Response: ${response.data}');
      }

      // Try to sync any pending offline location logs
      await _syncOfflineLocationLogs();
    } catch (e) {
      debugPrint('[RealtimeLocationService] ❌ Error sending location: $e');
      // If sending failed, save to offline storage as fallback
      try {
        await _saveLocationOffline(position);
      } catch (offlineError) {
        debugPrint(
          '[RealtimeLocationService] ❌ Failed to save offline: $offlineError',
        );
      }
    }
  }

  // Save location data to offline storage when offline
  Future<void> _saveLocationOffline(geolocator.Position position) async {
    try {
      // Format date sesuai dengan yang diharapkan API (YYYY-MM-DD)
      final dateString =
          _currentCheckInDate?.toIso8601String().split('T')[0] ??
          DateTime.now().toIso8601String().split('T')[0];

      // Get location info
      final locationInfo = _getLocationDurationInfo(
        position.latitude,
        position.longitude,
      );

      final offlineData = {
        'userId': _currentUserId,
        'attendanceId': _currentAttendanceId,
        'date': dateString,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'speed': position.speed,
        'heading': position.heading,
        'locationInfo': locationInfo,
        'areaInfo': {
          'currentLocation': locationInfo['currentLocation'],
          'stayDurations': locationInfo['stayDurations'],
          'totalStayDuration': locationInfo['totalStayDuration'],
          'totalLocations': locationInfo['totalLocations'],
          'recordedStays': locationInfo['recordedStays'],
          'durationMinutes': locationInfo['currentLocation']['durationMinutes'],
        },
        'savedAt': DateTime.now().toIso8601String(),
        'retryCount': 0,
      };

      await _offlineStorage.savePendingLocationLog(offlineData);
      debugPrint(
        '[RealtimeLocationService] 💾 Location saved offline - will sync when online',
      );
    } catch (e) {
      debugPrint(
        '[RealtimeLocationService] ❌ Error saving location offline: $e',
      );
    }
  }

  // Sync offline location logs when online
  Future<void> _syncOfflineLocationLogs() async {
    try {
      final pendingLogs = await _offlineStorage.getPendingLocationLogs();

      if (pendingLogs.isEmpty) {
        return; // Nothing to sync
      }

      debugPrint(
        '[RealtimeLocationService] 🔄 Syncing ${pendingLogs.length} offline location logs...',
      );

      int successCount = 0;
      int failCount = 0;

      for (int i = pendingLogs.length - 1; i >= 0; i--) {
        final logData = pendingLogs[i];

        try {
          // Try to send to server
          final response = await ApiService().post(
            '/api/supervisor/attendance/realtime/log',
            data: logData,
          );

          if (response.statusCode == 200) {
            // Success: remove from offline storage
            await _offlineStorage.removePendingLocationLog(i);
            successCount++;
            debugPrint(
              '[RealtimeLocationService] ✅ Synced offline log ${successCount}/${pendingLogs.length}',
            );
          } else {
            // Failed: increment retry count
            failCount++;
            logData['retryCount'] = (logData['retryCount'] ?? 0) + 1;

            // Remove if too many retries (prevent infinite retry)
            if (logData['retryCount'] > 5) {
              await _offlineStorage.removePendingLocationLog(i);
              debugPrint(
                '[RealtimeLocationService] 🗑️ Removed offline log after 5 failed retries',
              );
            }
          }
        } catch (e) {
          failCount++;
          debugPrint(
            '[RealtimeLocationService] ❌ Failed to sync offline log: $e',
          );
        }

        // Small delay to avoid overwhelming the server
        await Future.delayed(const Duration(milliseconds: 100));
      }

      debugPrint(
        '[RealtimeLocationService] 🔄 Offline sync completed: $successCount synced, $failCount failed',
      );
    } catch (e) {
      debugPrint('[RealtimeLocationService] ❌ Error syncing offline logs: $e');
    }
  }

  // Get location duration info untuk dikirim ke server dengan logic stay duration per koordinat
  Map<String, dynamic> _getLocationDurationInfo(
    double latitude,
    double longitude,
  ) {
    final now = DateTime.now();

    int latRounded = (latitude * 40)
        .round(); // ~25 meter precision (stay radius)
    int lngRounded = (longitude * 40).round();
    String currentLocationKey = '${latRounded}_${lngRounded}';

    debugPrint(
      '[RealtimeLocationService] 📊 Getting location duration info for $currentLocationKey',
    );

    // Collect semua FINAL stay durations yang >= 3 menit dari koordinat yang berbeda
    List<Map<String, dynamic>> stayDurations = [];
    int totalStayDuration = 0;

    _finalStayDurations.forEach((locationKey, duration) {
      // Hanya catat durasi >= 3 menit (sesuai logic user)
      if (duration >= 3) {
        // Parse koordinat dari locationKey
        List<String> parts = locationKey.split('_');
        if (parts.length == 2) {
          double coordLat = double.parse(parts[0]) / 40.0;
          double coordLng = double.parse(parts[1]) / 40.0;
          DateTime entryTime =
              _locationEntryTimes[locationKey] ?? DateTime.now();

          stayDurations.add({
            'locationKey': locationKey,
            'latitude': coordLat,
            'longitude': coordLng,
            'durationMinutes': duration,
            'entryTime': entryTime.toIso8601String(),
            'isCurrentLocation': locationKey == currentLocationKey,
          });

          totalStayDuration += duration;

          debugPrint(
            '[RealtimeLocationService] 📋 Including final stay: $locationKey = $duration minutes',
          );
          debugPrint(
            '[RealtimeLocationService] 🔍 Building location info - Final stays: ${_finalStayDurations.length}',
          );
        }
      }
    });

    // Info untuk lokasi saat ini - durasi real-time dari mulai masuk lokasi ini
    DateTime currentEntryTime = _locationEntryTimes[currentLocationKey] ?? now;
    Duration currentStayDuration = now.difference(currentEntryTime);
    int currentDuration = currentStayDuration.inMinutes;

    debugPrint(
      '[RealtimeLocationService] 📊 Current location duration: $currentLocationKey = $currentDuration minutes (since ${currentEntryTime.toIso8601String().split('T')[1].split('.')[0]})',
    );

    return {
      'currentLocation': {
        'locationKey': currentLocationKey,
        'latitude': latitude,
        'longitude': longitude,
        'durationMinutes': currentDuration,
        'entryTime': currentEntryTime.toIso8601String(),
      },
      'stayDurations':
          stayDurations, // Array durasi stay per koordinat (>= 3 menit)
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
      debugPrint(
        '[RealtimeLocationService] Clearing all old location duration data to prevent unrealistic durations',
      );
      _locationEntryTimes.clear();
      _locationDurationMinutes.clear();
      _finalStayDurations.clear();

      // Clear from persistent storage too
      await prefs.remove('location_entry_times');
      await prefs.remove('location_duration_minutes');
      await prefs.remove('final_stay_durations');

      // Fresh start - duration tracking will begin anew
      debugPrint(
        '[RealtimeLocationService] Location duration data cleared - fresh start',
      );
    } catch (e) {
      debugPrint(
        '[RealtimeLocationService] Error loading location duration data: $e',
      );
    }
  }

  // Save location duration data to persistent storage
  Future<void> _saveLocationDurationData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Convert maps to JSON
      final entryTimesJson = jsonEncode(
        _locationEntryTimes.map(
          (key, value) => MapEntry(key, value.toIso8601String()),
        ),
      );
      final durationJson = jsonEncode(_locationDurationMinutes);
      final finalStayJson = jsonEncode(_finalStayDurations);

      await prefs.setString('location_entry_times', entryTimesJson);
      await prefs.setString('location_duration_minutes', durationJson);
      await prefs.setString('final_stay_durations', finalStayJson);

      debugPrint(
        '[RealtimeLocationService] Saved ${_locationEntryTimes.length} location entries, ${_finalStayDurations.length} final stays',
      );
    } catch (e) {
      debugPrint(
        '[RealtimeLocationService] Error saving location duration data: $e',
      );
    }
  }

  // Sync pending location logs
  Future<void> syncPendingLocationLogs() async {
    debugPrint(
      '[RealtimeLocationService] Sync pending location logs - no pending logs to sync',
    );
    // For now, just log that there's nothing to sync
  }

  // Show local notification for location alerts
  Future<void> _showLocationAlert(
    String alertType,
    int minutes,
    double latitude,
    double longitude,
  ) async {
    try {
      // Format coordinates untuk display
      String coords =
          '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}';

      // Create notification content
      String title = '$alertType Alert - Lokasi';
      String body =
          'Anda telah di lokasi yang sama selama $minutes menit\nKoordinat: $coords';

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
