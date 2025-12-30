import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart' as geolocator;
import '../config/api_config.dart';
import '../models/user_model.dart';
import 'api_service.dart';

class _PendingStart {
  final User user;
  final String attendanceId;
  final DateTime checkInDate;
  final int intervalSeconds;

  _PendingStart({
    required this.user,
    required this.attendanceId,
    required this.checkInDate,
    required this.intervalSeconds,
  });
}

class RealtimeLocationService {
  final ApiService _apiService = ApiService();
  StreamSubscription<geolocator.Position>? _positionSubscription;
  geolocator.Position? _lastSentPosition;
  DateTime? _lastSentAt;
  bool _isTracking = false;
  int _intervalSeconds = 10; // Default 10 detik
  String? _activeUserId;
  String? _activeAttendanceId;
  DateTime? _activeCheckInDate;
  String? _activeDateKey;
  bool _startInProgress = false;
  bool _updateInProgress = false;
  _PendingStart? _pendingStart;

  // Movement threshold - hanya kirim jika bergerak >= 10 meter
  static const double MOVEMENT_THRESHOLD_METERS = 10.0;

  bool get isTracking => _isTracking;

  String _dateKey(DateTime value) {
    return value.toIso8601String().split('T')[0];
  }

  geolocator.LocationSettings _buildLocationSettings() {
    final distanceFilter = MOVEMENT_THRESHOLD_METERS.round();
    if (defaultTargetPlatform == TargetPlatform.android) {
      return geolocator.AndroidSettings(
        accuracy: geolocator.LocationAccuracy.high,
        distanceFilter: distanceFilter,
        intervalDuration: Duration(seconds: _intervalSeconds),
      );
    }
    return geolocator.LocationSettings(
      accuracy: geolocator.LocationAccuracy.high,
      distanceFilter: distanceFilter,
    );
  }

  void _startPositionStream() {
    _positionSubscription?.cancel();
    if (_activeUserId == null || _activeAttendanceId == null || _activeCheckInDate == null) {
      return;
    }

    _positionSubscription = geolocator.Geolocator.getPositionStream(
      locationSettings: _buildLocationSettings(),
    ).listen(
      (position) {
        final userId = _activeUserId;
        final attendanceId = _activeAttendanceId;
        final checkInDate = _activeCheckInDate;
        if (userId == null || attendanceId == null || checkInDate == null) {
          return;
        }
        _trackAndSendLocation(
          userId,
          attendanceId,
          checkInDate,
          positionOverride: position,
        );
      },
      onError: (error) {
        debugPrint('[RealtimeLocationService] Position stream error: $error');
      },
    );
  }

  /// Mulai tracking lokasi secara realtime setelah check-in
  Future<void> startRealtimeTracking({
    required User user,
    required String attendanceId,
    required DateTime checkInDate,
    int intervalSeconds = 10,
  }) async {
    if (attendanceId.isEmpty) {
      debugPrint('[RealtimeLocationService] Missing attendanceId, skip start');
      return;
    }
    final dateKey = _dateKey(checkInDate);
    final sameConfig = _isTracking &&
        _activeUserId == user.id &&
        _activeAttendanceId == attendanceId &&
        _activeDateKey == dateKey &&
        _intervalSeconds == intervalSeconds;
    if (sameConfig) {
      debugPrint('[RealtimeLocationService] Already tracking with same config, skip restart');
      return;
    }

    if (_startInProgress) {
      debugPrint('[RealtimeLocationService] Start in progress, queueing restart');
      _pendingStart = _PendingStart(
        user: user,
        attendanceId: attendanceId,
        checkInDate: checkInDate,
        intervalSeconds: intervalSeconds,
      );
      return;
    }

    _startInProgress = true;

    debugPrint('[RealtimeLocationService] Starting realtime location tracking...');
    debugPrint('[RealtimeLocationService] User: ${user.name} (${user.id})');
    debugPrint('[RealtimeLocationService] Interval: $intervalSeconds seconds');
    debugPrint('[RealtimeLocationService] Movement threshold: $MOVEMENT_THRESHOLD_METERS meters');

    try {
      if (_isTracking) {
        debugPrint('[RealtimeLocationService] Already tracking, stopping first...');
        await stopRealtimeTracking();
      }

      _activeUserId = user.id;
      _activeAttendanceId = attendanceId;
      _activeCheckInDate = checkInDate;
      _activeDateKey = dateKey;
      _isTracking = true;
      _intervalSeconds = intervalSeconds;
      _lastSentPosition = null;
      _lastSentAt = null;

      // Kirim lokasi awal (lokasi check-in) - dapatkan GPS location yang sebenarnya
      final initialPosition = await _getCurrentPosition();
      if (initialPosition == null) {
        await stopRealtimeTracking();
        return;
      }
      await _trackAndSendLocation(
        user.id,
        attendanceId,
        checkInDate,
        positionOverride: initialPosition,
      );

      // Mulai stream untuk tracking berkala
      _startPositionStream();

      debugPrint('[RealtimeLocationService] Realtime tracking started');
    } finally {
      _startInProgress = false;
      if (_pendingStart != null) {
        final pending = _pendingStart!;
        _pendingStart = null;
        await startRealtimeTracking(
          user: pending.user,
          attendanceId: pending.attendanceId,
          checkInDate: pending.checkInDate,
          intervalSeconds: pending.intervalSeconds,
        );
      }
    }
  }

  /// Berhenti tracking lokasi (saat check-out)
  Future<void> stopRealtimeTracking() async {
    if (!_isTracking) return;

    debugPrint('[RealtimeLocationService] Stopping realtime location tracking...');

    _positionSubscription?.cancel();
    _positionSubscription = null;
    _lastSentPosition = null;
    _lastSentAt = null;
    _activeUserId = null;
    _activeAttendanceId = null;
    _activeCheckInDate = null;
    _activeDateKey = null;
    _pendingStart = null;
    _startInProgress = false;
    _updateInProgress = false;
    _isTracking = false;

    debugPrint('[RealtimeLocationService] Realtime tracking stopped');
  }

  /// Track dan kirim lokasi saat ini
  Future<void> _trackAndSendLocation(
    String userId,
    String attendanceId,
    DateTime checkInDate, {
    geolocator.Position? positionOverride,
  }) async {
    if (!_isTracking) return;
    if (_updateInProgress) {
      debugPrint('[RealtimeLocationService] Update in progress, skipping');
      return;
    }
    if (userId.isEmpty) {
      debugPrint('[RealtimeLocationService] Missing userId, skipping location update');
      return;
    }
    if (attendanceId.isEmpty) {
      debugPrint('[RealtimeLocationService] Missing attendanceId, skipping location update');
      return;
    }

    final now = DateTime.now();
    if (_lastSentAt != null &&
        now.difference(_lastSentAt!).inSeconds < _intervalSeconds) {
      return;
    }

    _updateInProgress = true;
    try {
      final position = positionOverride ?? await _getCurrentPosition();
      if (position == null) {
        return;
      }

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
          return;
        }
      }

      // Kirim lokasi baru
      await _sendLocationLog(
        userId: userId,
        attendanceId: attendanceId,
        latitude: position.latitude,
        longitude: position.longitude,
        date: checkInDate,
        accuracy: position.accuracy,
        speed: position.speed,
        heading: position.heading,
      );

      _lastSentPosition = position;
      _lastSentAt = DateTime.now();
    } catch (e) {
      debugPrint('[RealtimeLocationService] Error tracking location: $e');
      // Jangan throw error agar tracking terus berjalan
    } finally {
      _updateInProgress = false;
    }
  }

  Future<geolocator.Position?> _getCurrentPosition() async {
    // Cek permission GPS
    debugPrint('[RealtimeLocationService] Checking GPS permission...');
    final permission = await geolocator.Geolocator.checkPermission();
    debugPrint('[RealtimeLocationService] GPS permission status: $permission');

    if (permission != geolocator.LocationPermission.whileInUse &&
        permission != geolocator.LocationPermission.always) {
      debugPrint('[RealtimeLocationService] No GPS permission, requesting permission...');
      final requestedPermission = await geolocator.Geolocator.requestPermission();
      debugPrint('[RealtimeLocationService] Requested permission result: $requestedPermission');

      if (requestedPermission != geolocator.LocationPermission.whileInUse &&
          requestedPermission != geolocator.LocationPermission.always) {
        debugPrint('[RealtimeLocationService] GPS permission denied, skipping location update');
        return null;
      }
    }

    // Cek apakah location service enabled
    debugPrint('[RealtimeLocationService] Checking if location service is enabled...');
    final serviceEnabled = await geolocator.Geolocator.isLocationServiceEnabled();
    debugPrint('[RealtimeLocationService] Location service enabled: $serviceEnabled');

    if (!serviceEnabled) {
      debugPrint('[RealtimeLocationService] Location service disabled, skipping location update');
      return null;
    }

    // Ambil posisi saat ini
    debugPrint('[RealtimeLocationService] Getting current position...');
    final position = await geolocator.Geolocator.getCurrentPosition(
      desiredAccuracy: geolocator.LocationAccuracy.high,
      timeLimit: const Duration(seconds: 10),
    );
    debugPrint('[RealtimeLocationService] Got position: ${position.latitude}, ${position.longitude} (accuracy: ${position.accuracy}m)');
    return position;
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
    if (_intervalSeconds == newIntervalSeconds) {
      return;
    }

    debugPrint('[RealtimeLocationService] Updating tracking interval: $_intervalSeconds -> $newIntervalSeconds seconds');
    _intervalSeconds = newIntervalSeconds;

    if (_isTracking && _activeUserId != null && _activeAttendanceId != null && _activeCheckInDate != null) {
      _startPositionStream();
    }
  }
}

