import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:geolocator/geolocator.dart' as geolocator;

import '../config/api_config.dart';
import 'api_service.dart';
import 'offline_storage_service.dart';
import 'tracking_state_service.dart';

const double _movementThresholdMeters = 10.0;

class BackgroundTrackingService {
  static const String _channelId = 'atenim_tracking';
  static const int _notificationId = 888;

  static Future<void> initialize() async {
    final service = FlutterBackgroundService();
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: backgroundTrackingEntryPoint,
        autoStart: false, // Jangan auto start - akan dimulai manual saat check-in
        isForegroundMode: true,
        notificationChannelId: "atenim_service",
        initialNotificationTitle: 'Atenim Active',
        initialNotificationContent: 'Layanan pelacakan lokasi berjalan',
        foregroundServiceNotificationId: _notificationId,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: backgroundTrackingEntryPoint,
        onBackground: _onIosBackground,
      ),
    );
  }

  static Future<void> ensureRunning() async {
    final service = FlutterBackgroundService();
    final isRunning = await service.isRunning();
    if (!isRunning) {
      await service.startService();
    }
  }

  static Future<void> stop() async {
    final service = FlutterBackgroundService();
    final isRunning = await service.isRunning();
    if (isRunning) {
      service.invoke('stopService');
    }
  }
}

@pragma('vm:entry-point')
Future<bool> _onIosBackground(ServiceInstance service) async {
  return true;
}

geolocator.LocationSettings _buildLocationSettings(int intervalSeconds) {
  final distanceFilter = _movementThresholdMeters.round();
  if (defaultTargetPlatform == TargetPlatform.android) {
    // Nonaktifkan foreground notification karena background service sudah menanganinya
    return geolocator.AndroidSettings(
      accuracy: geolocator.LocationAccuracy.high,
      distanceFilter: distanceFilter,
      intervalDuration: Duration(seconds: intervalSeconds),
      foregroundNotificationConfig: null, // Disabled - handled by background service
      forceLocationManager: false, // Use default provider
    );
  }
  return geolocator.LocationSettings(
    accuracy: geolocator.LocationAccuracy.high,
    distanceFilter: distanceFilter,
  );
}

@pragma('vm:entry-point')
void backgroundTrackingEntryPoint(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {}

  if (service is AndroidServiceInstance) {
    service.setAsForegroundService();
  }

  final apiService = ApiService();
  final offlineStorage = OfflineStorageService();
  StreamSubscription<geolocator.Position>? subscription;
  TrackingState? currentState;
  geolocator.Position? lastSentPosition;
  DateTime? lastSentAt;

  Future<void> stopStream() async {
    await subscription?.cancel();
    subscription = null;
    lastSentPosition = null;
    lastSentAt = null;
  }

  Future<void> sendLocation({
    required TrackingState state,
    required geolocator.Position position,
  }) async {
    try {
      final payload = {
        'userId': state.userId,
        'attendanceId': state.attendanceId,
        'date': state.checkInDate.toIso8601String().split('T')[0],
        'latitude': position.latitude,
        'longitude': position.longitude,
        if (position.accuracy >= 0) 'accuracy': position.accuracy,
        if (position.speed >= 0) 'speed': position.speed,
        if (position.heading >= 0) 'heading': position.heading,
      };

      final response = await apiService.post(ApiConfig.realtimeLog, data: payload);
      if (response.statusCode != 200) {
        await offlineStorage.savePendingLocationLog({
          ...payload,
          'capturedAt': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      await offlineStorage.savePendingLocationLog({
        'userId': state.userId,
        'attendanceId': state.attendanceId,
        'date': state.checkInDate.toIso8601String().split('T')[0],
        'latitude': position.latitude,
        'longitude': position.longitude,
        if (position.accuracy >= 0) 'accuracy': position.accuracy,
        if (position.speed >= 0) 'speed': position.speed,
        if (position.heading >= 0) 'heading': position.heading,
        'capturedAt': DateTime.now().toIso8601String(),
      });
    }
  }

  Future<void> startStream(TrackingState state) async {
    await stopStream();

    final permission = await geolocator.Geolocator.checkPermission();
    if (permission != geolocator.LocationPermission.always &&
        permission != geolocator.LocationPermission.whileInUse) {
      return;
    }

    final serviceEnabled = await geolocator.Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return;
    }

    subscription = geolocator.Geolocator.getPositionStream(
      locationSettings: _buildLocationSettings(state.intervalSeconds),
    ).listen((position) async {
      final activeState = await TrackingStateService.getTrackingState();
      if (activeState == null) {
        debugPrint('[BackgroundTracking] No active tracking state, skipping...');
        return;
      }

      // Background service runs continuously when there's active attendance
      // It will handle location tracking regardless of app foreground/background state
      debugPrint('[BackgroundTracking] Background location update received');

      final now = DateTime.now();
      if (lastSentAt != null &&
          now.difference(lastSentAt!).inSeconds < activeState.intervalSeconds) {
        debugPrint('[BackgroundTracking] Too soon since last update (${now.difference(lastSentAt!).inSeconds}s < ${activeState.intervalSeconds}s)');
        return;
      }

      if (lastSentPosition != null) {
        final distance = geolocator.Geolocator.distanceBetween(
          lastSentPosition!.latitude,
          lastSentPosition!.longitude,
          position.latitude,
          position.longitude,
        );
        if (distance < _movementThresholdMeters) {
          debugPrint('[BackgroundTracking] Movement too small (${distance.toStringAsFixed(1)}m < ${_movementThresholdMeters}m)');
          return;
        }
      }

      debugPrint('[BackgroundTracking] Sending background location update...');
      await sendLocation(state: activeState, position: position);
      lastSentPosition = position;
      lastSentAt = DateTime.now();
    });
  }

  Future<void> syncPendingLogs() async {
    final pending = await offlineStorage.getPendingLocationLogs();
    if (pending.isEmpty) {
      return;
    }

    for (int i = pending.length - 1; i >= 0; i--) {
      final item = pending[i];
      final userId = item['userId']?.toString() ?? '';
      final attendanceId = item['attendanceId']?.toString() ?? '';
      final date = item['date']?.toString() ?? '';
      final latitude = item['latitude'];
      final longitude = item['longitude'];

      if (userId.isEmpty || attendanceId.isEmpty || date.isEmpty) {
        await offlineStorage.removePendingLocationLog(i);
        continue;
      }

      if (latitude == null || longitude == null) {
        await offlineStorage.removePendingLocationLog(i);
        continue;
      }

      try {
        final response = await apiService.post(
          ApiConfig.realtimeLog,
          data: {
            'userId': userId,
            'attendanceId': attendanceId,
            'date': date,
            'latitude': latitude,
            'longitude': longitude,
            if (item['accuracy'] != null) 'accuracy': item['accuracy'],
            if (item['speed'] != null) 'speed': item['speed'],
            if (item['heading'] != null) 'heading': item['heading'],
            if (item['capturedAt'] != null) 'capturedAt': item['capturedAt'],
          },
        );

        if (response.statusCode == 200) {
          await offlineStorage.removePendingLocationLog(i);
        }
      } catch (_) {}
    }
  }

  Future<void> refreshTrackingState() async {
    final nextState = await TrackingStateService.getTrackingState();
    if (nextState == null) {
      currentState = null;
      await stopStream();
      return;
    }

    final shouldRestart = currentState == null ||
        currentState!.attendanceId != nextState.attendanceId ||
        currentState!.intervalSeconds != nextState.intervalSeconds;

    currentState = nextState;
    if (shouldRestart) {
      await startStream(nextState);
    } else if (subscription == null) {
      await startStream(nextState);
    }
  }

  service.on('stopService').listen((_) async {
    await stopStream();
    service.stopSelf();
  });

  await refreshTrackingState();
  await syncPendingLogs();
  Timer.periodic(const Duration(seconds: 15), (_) async {
    await refreshTrackingState();
    await syncPendingLogs();
  });
}
