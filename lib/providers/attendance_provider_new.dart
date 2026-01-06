import 'package:flutter/foundation.dart';
import 'dart:io';
import '../models/attendance_model.dart';
import '../models/user_model.dart' show User;
import '../services/attendance_service.dart';
import '../services/realtime_location_service.dart';
import '../services/offline_storage_service.dart';
import '../services/background_tracking_service.dart';
import '../services/persistent_notification_service.dart';
import '../services/auth_service.dart';
import '../utils/error_handler.dart';
import 'connectivity_provider.dart';

class AttendanceProvider with ChangeNotifier {
  final AttendanceService _attendanceService = AttendanceService();
  final RealtimeLocationService _realtimeService = RealtimeLocationService();
  final OfflineStorageService _offlineStorage = OfflineStorageService();
  final AuthService _authService = AuthService();
  ConnectivityProvider? _connectivityProvider;
  AttendancePayload? _attendanceData;
  bool _isLoading = false;
  String? _error;
  bool _isOfflineMode = false;
  bool _syncPendingInProgress = false;

  // Flags to prevent double initialization
  bool _backgroundTrackingInitialized = false;
  bool _realtimeTrackingInitialized = false;

  // Flags to prevent double API calls
  bool _checkInInProgress = false;
  bool _checkOutInProgress = false;
  bool _loadAttendanceInProgress = false;

  AttendancePayload? get attendanceData => _attendanceData;
  AttendanceRecord? get todayAttendance => _attendanceData?.today;
  List<AttendanceRecord> get recentAttendance => _attendanceData?.recent ?? [];
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isOfflineMode => _isOfflineMode;
  bool get isRealtimeTracking => _realtimeService.isTracking;

  @override
  void dispose() {
    _connectivityProvider?.removeListener(_handleConnectivityChange);
    super.dispose();
  }

  void setConnectivityProvider(ConnectivityProvider provider) {
    if (_connectivityProvider == provider) {
      return;
    }
    _connectivityProvider?.removeListener(_handleConnectivityChange);
    _connectivityProvider = provider;
    _connectivityProvider?.addListener(_handleConnectivityChange);
  }

  void setForegroundActive(bool value) {
    // Temporary implementation until method is added to RealtimeLocationService
    debugPrint('[AttendanceProvider] Foreground status changed: $value');
  }

  void _handleConnectivityChange() {
    final isConnected = _connectivityProvider?.isConnected ?? true;
    if (!isConnected) {
      return;
    }
    syncPendingAttendance();
    // _realtimeService.syncPendingLocationLogs();
    syncRealtimeTracking();
    ensureBackgroundTracking(); // Pastikan background service running
  }

  Future<void> _ensureRealtimeTracking() async {
    if (_realtimeTrackingInitialized || _realtimeService.isTracking) {
      return;
    }

    final today = todayAttendance;
    if (today == null || today.checkIn == null || today.checkOut != null) {
      return;
    }

    if (today.id.isEmpty) {
      debugPrint('[AttendanceProvider] Cannot start tracking: attendanceId kosong');
      return;
    }

    User? user;
    try {
      user = await _authService.getCurrentUser();
    } catch (_) {
      user = null;
    }
    if (user == null) {
      debugPrint('[AttendanceProvider] Cannot start tracking: user null');
      return;
    }

    DateTime checkInDate;
    try {
      checkInDate = DateTime.parse(today.date);
    } catch (_) {
      checkInDate = DateTime.now();
    }

    try {
      await _realtimeService.startRealtimeTracking(
        user: user,
        attendanceId: today.id,
        checkInDate: checkInDate,
        intervalSeconds: 10,
      );
      _realtimeTrackingInitialized = true;
      debugPrint('[AttendanceProvider] ✓ Realtime tracking started (auto sync)');
    } catch (e) {
      debugPrint('[AttendanceProvider] Failed to auto-start tracking: $e');
    }
  }

  Future<void> loadAttendance({DateTime? startDate, DateTime? endDate, bool forceRefresh = false}) async {
    // Prevent double load calls
    if (_loadAttendanceInProgress) {
      debugPrint('[AttendanceProvider] Load attendance already in progress, ignoring duplicate call');
      return;
    }

    debugPrint('[AttendanceProvider] Loading attendance... (forceRefresh: $forceRefresh)');
    _loadAttendanceInProgress = true;

    // Load from local storage first (instant display)
    if (!forceRefresh) {
      final offlineData = await _offlineStorage.getAttendance();
      if (offlineData != null) {
        _attendanceData = AttendancePayload.fromJson(offlineData);
        _isOfflineMode = false;
        _error = null;
        _isLoading = false;
        notifyListeners();
        debugPrint('[AttendanceProvider] ✓ Attendance loaded instantly from offline storage');
      }
    }

    // Check connectivity
    final isConnected = _connectivityProvider?.isConnected ?? true;
    _isOfflineMode = !isConnected;

    // Set loading only if we don't have cached data
    if (_attendanceData == null || forceRefresh) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    try {
      if (isConnected) {
        // Try to load from API in background
        try {
          final freshData = await _attendanceService.getAttendance(
            startDate: startDate,
            endDate: endDate,
          );
          // Save to offline storage
          await _offlineStorage.saveAttendance({
            'today': freshData.today?.toJson(),
            'recent': freshData.recent.map((e) => e.toJson()).toList(),
          });
          _attendanceData = freshData;
          _error = null;
          _isOfflineMode = false;
          debugPrint('[AttendanceProvider] ✓ Attendance refreshed from API');
        } catch (e) {
          // If API fails, keep using cached data if available
          if (_attendanceData == null) {
            debugPrint('[AttendanceProvider] ⚠ API failed, trying offline storage...');
            final offlineData = await _offlineStorage.getAttendance();
            if (offlineData != null && offlineData.isNotEmpty) {
              _attendanceData = AttendancePayload.fromJson(offlineData);
              _isOfflineMode = true;
              _error = 'Mode offline - Data terakhir yang tersimpan';
              debugPrint('[AttendanceProvider] ✓ Attendance loaded from offline storage');
            } else {
              throw e;
            }
          } else {
            // Keep using cached data, just mark as offline
            _isOfflineMode = true;
            _error = 'Mode offline - Data terakhir yang tersimpan';
            debugPrint('[AttendanceProvider] ⚠ API failed, using cached data');
          }
        }
      } else {
        // Offline mode - use cached data if available
        if (_attendanceData == null) {
          final offlineData = await _offlineStorage.getAttendance();
          if (offlineData != null) {
            _attendanceData = AttendancePayload.fromJson(offlineData);
            _isOfflineMode = true;
            _error = 'Mode offline - Data terakhir yang tersimpan';
            debugPrint('[AttendanceProvider] ✓ Attendance loaded from offline storage');
          } else {
            throw Exception('Tidak ada data offline tersedia');
          }
        } else {
          _isOfflineMode = true;
          _error = 'Mode offline - Data terakhir yang tersimpan';
        }
      }

      if (_attendanceData?.today != null) {
        debugPrint('[AttendanceProvider] Today: ${_attendanceData!.today!.checkIn} - ${_attendanceData!.today!.checkOut}');

        // Restore persistent notification if check-in is active
        final today = _attendanceData!.today!;
        if (today.checkIn != null && today.checkOut == null) {
          try {
            await PersistentNotificationService.showCheckInNotification(today);
            PersistentNotificationService.startPeriodicUpdates(today);
            debugPrint('[AttendanceProvider] ✓ Persistent notification restored for active check-in');
          } catch (e) {
            debugPrint('[AttendanceProvider] Failed to restore persistent notification: $e');
          }
        }
      }
    } catch (e) {
      if (_attendanceData == null) {
        _error = ErrorHandler.getErrorMessage(e);
        _attendanceData = null;
        debugPrint('[AttendanceProvider] ✗ Error loading attendance: $_error');
      } else {
        // Keep cached data even if refresh fails
        debugPrint('[AttendanceProvider] ⚠ Refresh failed, keeping cached data: $e');
      }
    } finally {
      _isLoading = false;
      _loadAttendanceInProgress = false;

      // Only initialize tracking services if we don't have attendance data yet
      // This prevents double initialization on every loadAttendance call
      if (_attendanceData?.today != null) {
        await _ensureRealtimeTracking();
        await ensureBackgroundTracking();
      }

      notifyListeners();
    }
  }

  double? _parseCoordinate(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  Future<bool> checkIn({
    required File photo,
    String? shiftId,
    double? latitude,
    double? longitude,
  }) async {
    // Prevent double check-in calls
    if (_checkInInProgress) {
      debugPrint('[AttendanceProvider] Check-in already in progress, ignoring duplicate call');
      return false;
    }

    debugPrint('[AttendanceProvider] Check-in initiated');
    debugPrint('[AttendanceProvider] Shift ID: ${shiftId ?? "null (no shift)"}');
    _isLoading = true;
    _error = null;
    _checkInInProgress = true;
    notifyListeners();

    final isConnected = _connectivityProvider?.isConnected ?? true;
    User? sessionUser;
    double? resolvedLatitude = latitude;
    double? resolvedLongitude = longitude;

    try {
      if (resolvedLatitude == null || resolvedLongitude == null) {
        final location = await _attendanceService.getRequiredLocation(actionLabel: 'check-in');
        resolvedLatitude = location['latitude'];
        resolvedLongitude = location['longitude'];
      }

      if (resolvedLatitude == null || resolvedLongitude == null) {
        throw Exception('GPS wajib aktif untuk check-in.');
      }

      if (isConnected) {
        // Try to check-in online
        try {
          try {
            sessionUser = await _authService.getCurrentUser();
          } catch (_) {
            sessionUser = null;
          }

          final result = await _attendanceService.checkIn(
            photo: photo,
            shiftId: shiftId, // Opsional - bisa null
            latitude: resolvedLatitude,
            longitude: resolvedLongitude,
            site: sessionUser?.site,
          );

          if (result['success'] == true) {
            debugPrint('[AttendanceProvider] ✓ Check-in successful, reloading attendance...');

            // Load attendance dengan forceRefresh untuk mendapatkan data terbaru
            final now = DateTime.now();
            final responseData = result['data'];
            String? responseAttendanceId;
            DateTime? responseCheckInDate;
            if (responseData is Map) {
              final rawId = responseData['id'];
              if (rawId is String && rawId.isNotEmpty) {
                responseAttendanceId = rawId;
              }
              final rawDate = responseData['date'];
              if (rawDate is String && rawDate.isNotEmpty) {
                try {
                  responseCheckInDate = DateTime.parse(rawDate);
                } catch (_) {}
              }
            }
            bool trackingStarted = false;
            final startDate = DateTime(now.year, now.month, 1);
            await loadAttendance(
              startDate: startDate,
              endDate: now,
              forceRefresh: true,
            );

            // Start realtime location tracking setelah check-in berhasil
            try {
              debugPrint('[AttendanceProvider] Starting realtime location tracking...');
              final user = sessionUser ?? await _authService.getCurrentUser();
              debugPrint('[AttendanceProvider] Current user: ${user?.name} (${user?.id})');

              if (user != null && responseAttendanceId != null) {
                debugPrint('[AttendanceProvider] Using attendance ID from response: $responseAttendanceId');
                await _realtimeService.startRealtimeTracking(
                  user: user,
                  attendanceId: responseAttendanceId,
                  checkInDate: responseCheckInDate ?? now,
                  intervalSeconds: 10,
                );
                trackingStarted = true;
                debugPrint('[AttendanceProvider] ?o" Realtime tracking started (response record)');
              }

              if (!trackingStarted) {
                // Wait a bit for attendance data to be updated
                await Future.delayed(const Duration(milliseconds: 500));

                final todayRecord = todayAttendance;
                debugPrint('[AttendanceProvider] Today attendance: ${todayRecord?.checkIn} - ${todayRecord?.checkOut}, ID: ${todayRecord?.id}');

                if (user != null && todayRecord != null) {
                  debugPrint('[AttendanceProvider] ?o. User and attendance record available');

                  // Use attendance ID if available, otherwise use a temporary ID
                  final attendanceId = todayRecord.id.isNotEmpty ? todayRecord.id : 'temp-${user.id}-${now.millisecondsSinceEpoch}';
                  debugPrint('[AttendanceProvider] Using attendance ID: $attendanceId');

                  await _realtimeService.startRealtimeTracking(
                    user: user,
                    attendanceId: attendanceId,
                    checkInDate: now,
                    intervalSeconds: 10,
                  );
                  debugPrint('[AttendanceProvider] ?o" Realtime tracking started successfully');
                } else {
                  debugPrint('[AttendanceProvider] ??O Cannot start tracking: user=${user != null}, todayRecord=${todayRecord != null}');
                }
              }
            } catch (e) {
              debugPrint('[AttendanceProvider] ❌ Failed to start realtime tracking: $e');
              debugPrint('[AttendanceProvider] Stack trace: ${e.toString()}');
              // Don't fail check-in just because tracking failed
            }

            // Pastikan background tracking service juga running
            try {
              await ensureBackgroundTracking();
            } catch (e) {
              debugPrint('[AttendanceProvider] Failed to ensure background tracking after check-in: $e');
            }

            // Show persistent notification for active check-in
            try {
              if (todayAttendance != null) {
                await PersistentNotificationService.showCheckInNotification(todayAttendance!);
                PersistentNotificationService.startPeriodicUpdates(todayAttendance!);
              }
            } catch (e) {
              debugPrint('[AttendanceProvider] Failed to show persistent notification: $e');
            }

            return true;
          } else {
            _error = result['message'] as String? ?? 'Check-in gagal';
            debugPrint('[AttendanceProvider] ✗ Check-in failed: $_error');
            return false;
          }
        } catch (e) {
          // Check if it's a memory-related error
          final errorStr = e.toString().toLowerCase();
          if (errorStr.contains('memory') || 
              errorStr.contains('outofmemory') ||
              errorStr.contains('terlalu besar') ||
              errorStr.contains('timeout')) {
            // Don't save to pending for memory/timeout errors - user needs to retry with smaller photo
            _error = ErrorHandler.getErrorMessage(e);
            debugPrint('[AttendanceProvider] ✗ Check-in failed due to memory/timeout: $_error');
            return false;
          }
          
          // If online check-in fails for other reasons, save to pending
          debugPrint('[AttendanceProvider] ⚠ Online check-in failed, saving to pending...');
          try {
            await _offlineStorage.savePendingCheckIn({
              'photo': photo.path,
              'shiftId': shiftId,
              'latitude': resolvedLatitude,
              'longitude': resolvedLongitude,
            });
            _error = 'Check-in disimpan untuk sync nanti';
            debugPrint('[AttendanceProvider] ✓ Check-in saved to pending');
            return true;
          } catch (saveError) {
            debugPrint('[AttendanceProvider] ✗ Failed to save to pending: $saveError');
            _error = ErrorHandler.getErrorMessage(e);
            return false;
          }
        }
      } else {
        // Save to pending for offline mode
        debugPrint('[AttendanceProvider] ⚠ Offline mode, saving check-in to pending...');
        await _offlineStorage.savePendingCheckIn({
          'photo': photo.path,
          'shiftId': shiftId,
          'latitude': resolvedLatitude,
          'longitude': resolvedLongitude,
        });
        _error = 'Mode offline - Check-in akan disinkronkan saat online';
        debugPrint('[AttendanceProvider] ✓ Check-in saved to pending');
        return true;
      }
    } catch (e) {
      _error = ErrorHandler.getErrorMessage(e);
      debugPrint('[AttendanceProvider] ✗ Check-in exception: $e');
      debugPrint('[AttendanceProvider] User-friendly error: $_error');
      return false;
    } finally {
      _isLoading = false;
      _checkInInProgress = false;
      notifyListeners();
    }
  }

  Future<bool> checkOut({
    required File photo,
    double? latitude,
    double? longitude,
  }) async {
    // Prevent double check-out calls
    if (_checkOutInProgress) {
      debugPrint('[AttendanceProvider] Check-out already in progress, ignoring duplicate call');
      return false;
    }

    debugPrint('[AttendanceProvider] Check-out initiated');
    _isLoading = true;
    _error = null;
    _checkOutInProgress = true;
    notifyListeners();

    final isConnected = _connectivityProvider?.isConnected ?? true;
    double? resolvedLatitude = latitude;
    double? resolvedLongitude = longitude;

    try {
      if (resolvedLatitude == null || resolvedLongitude == null) {
        final location = await _attendanceService.getRequiredLocation(actionLabel: 'check-out');
        resolvedLatitude = location['latitude'];
        resolvedLongitude = location['longitude'];
      }

      if (resolvedLatitude == null || resolvedLongitude == null) {
        throw Exception('GPS wajib aktif untuk check-out.');
      }

      if (isConnected) {
        // Try to check-out online
        try {
          User? sessionUser;
          try {
            sessionUser = await _authService.getCurrentUser();
          } catch (_) {
            sessionUser = null;
          }

          final result = await _attendanceService.checkOut(
            photo: photo,
            latitude: resolvedLatitude,
            longitude: resolvedLongitude,
            site: sessionUser?.site,
          );

          if (result['success'] == true) {
            debugPrint('[AttendanceProvider] ✓ Check-out successful, reloading attendance...');
            // Reset loading sebelum loadAttendance untuk menghindari loading state yang stuck
            _isLoading = false;
            notifyListeners();

            // Stop realtime location tracking setelah check-out berhasil
            try {
              debugPrint('[AttendanceProvider] Stopping realtime location tracking...');
              await _realtimeService.stopRealtimeTracking();
              debugPrint('[AttendanceProvider] ✓ Realtime tracking stopped');
            } catch (e) {
              debugPrint('[AttendanceProvider] Failed to stop realtime tracking: $e');
              // Don't fail check-out just because tracking stop failed
            }

            // Hide persistent notification after successful check-out
            try {
              await PersistentNotificationService.hideCheckInNotification();
              PersistentNotificationService.stopPeriodicUpdates();
              debugPrint('[AttendanceProvider] ✓ Persistent notification hidden');
            } catch (e) {
              debugPrint('[AttendanceProvider] Failed to hide persistent notification: $e');
            }

            // Reset initialization flags for next check-in
            _backgroundTrackingInitialized = false;
            _realtimeTrackingInitialized = false;

            // Load attendance dengan forceRefresh untuk mendapatkan data terbaru
            final now = DateTime.now();
            final startDate = DateTime(now.year, now.month, 1);
            await loadAttendance(
              startDate: startDate,
              endDate: now,
              forceRefresh: true,
            );
            return true;
          } else {
            _error = result['message'] as String? ?? 'Check-out gagal';
            debugPrint('[AttendanceProvider] ✗ Check-out failed: $_error');
            return false;
          }
        } catch (e) {
          // Check if it's a memory-related error
          final errorStr = e.toString().toLowerCase();
          if (errorStr.contains('memory') || 
              errorStr.contains('outofmemory') ||
              errorStr.contains('terlalu besar') ||
              errorStr.contains('timeout')) {
            // Don't save to pending for memory/timeout errors - user needs to retry with smaller photo
            _error = ErrorHandler.getErrorMessage(e);
            debugPrint('[AttendanceProvider] ✗ Check-out failed due to memory/timeout: $_error');
            return false;
          }
          
          // If online check-out fails for other reasons, save to pending
          debugPrint('[AttendanceProvider] ⚠ Online check-out failed, saving to pending...');
          try {
            await _offlineStorage.savePendingCheckOut({
              'photo': photo.path,
              'latitude': resolvedLatitude,
              'longitude': resolvedLongitude,
            });
            _error = 'Check-out disimpan untuk sync nanti';
            debugPrint('[AttendanceProvider] ✓ Check-out saved to pending');
            return true;
          } catch (saveError) {
            debugPrint('[AttendanceProvider] ✗ Failed to save to pending: $saveError');
            _error = ErrorHandler.getErrorMessage(e);
            return false;
          }
        }
      } else {
        // Save to pending for offline mode
        debugPrint('[AttendanceProvider] ⚠ Offline mode, saving check-out to pending...');
        await _offlineStorage.savePendingCheckOut({
          'photo': photo.path,
          'latitude': resolvedLatitude,
          'longitude': resolvedLongitude,
        });
        _error = 'Mode offline - Check-out akan disinkronkan saat online';
        debugPrint('[AttendanceProvider] ✓ Check-out saved to pending');
        return true;
      }
    } catch (e) {
      _error = ErrorHandler.getErrorMessage(e);
      debugPrint('[AttendanceProvider] ✗ Check-out exception: $e');
      debugPrint('[AttendanceProvider] User-friendly error: $_error');
      return false;
    } finally {
      _isLoading = false;
      _checkOutInProgress = false;
      notifyListeners();
    }
  }

  Future<void> syncPendingAttendance() async {
    if (_syncPendingInProgress) {
      return;
    }

    final isConnected = _connectivityProvider?.isConnected ?? true;
    if (!isConnected) {
      return;
    }

    _syncPendingInProgress = true;
    try {
      final checkInSynced = await _syncPendingCheckIns();
      final checkOutSynced = await _syncPendingCheckOuts();
      // await _realtimeService.syncPendingLocationLogs();
      if (checkInSynced || checkOutSynced) {
        final now = DateTime.now();
        final startDate = DateTime(now.year, now.month, 1);
        await loadAttendance(
          startDate: startDate,
          endDate: now,
          forceRefresh: true,
        );
      }
    } finally {
      _syncPendingInProgress = false;
    }
  }

  Future<bool> _syncPendingCheckIns() async {
    final pending = await _offlineStorage.getPendingCheckIns();
    if (pending.isEmpty) {
      return false;
    }

    User? sessionUser;
    try {
      sessionUser = await _authService.getCurrentUser();
    } catch (_) {
      sessionUser = null;
    }

    var synced = false;
    for (int i = pending.length - 1; i >= 0; i--) {
      final item = pending[i];
      final photoPath = item['photo']?.toString();
      if (photoPath == null || photoPath.isEmpty) {
        await _offlineStorage.removePendingCheckIn(i);
        continue;
      }

      final file = File(photoPath);
      if (!await file.exists()) {
        await _offlineStorage.removePendingCheckIn(i);
        continue;
      }

      final shiftId = item['shiftId']?.toString();
      final latitude = _parseCoordinate(item['latitude']);
      final longitude = _parseCoordinate(item['longitude']);
      final result = await _attendanceService.checkIn(
        photo: file,
        shiftId: shiftId,
        latitude: latitude,
        longitude: longitude,
        site: sessionUser?.site,
      );

      if (result['success'] == true) {
        await _offlineStorage.removePendingCheckIn(i);
        synced = true;
      } else {
        final message = (result['message'] ?? '').toString().toLowerCase();
        if (message.contains('sudah check-in') || message.contains('already')) {
          await _offlineStorage.removePendingCheckIn(i);
        }
      }
    }

    return synced;
  }

  Future<bool> _syncPendingCheckOuts() async {
    final pending = await _offlineStorage.getPendingCheckOuts();
    if (pending.isEmpty) {
      return false;
    }

    User? sessionUser;
    try {
      sessionUser = await _authService.getCurrentUser();
    } catch (_) {
      sessionUser = null;
    }

    var synced = false;
    for (int i = pending.length - 1; i >= 0; i--) {
      final item = pending[i];
      final photoPath = item['photo']?.toString();
      if (photoPath == null || photoPath.isEmpty) {
        await _offlineStorage.removePendingCheckOut(i);
        continue;
      }

      final file = File(photoPath);
      if (!await file.exists()) {
        await _offlineStorage.removePendingCheckOut(i);
        continue;
      }

      final latitude = _parseCoordinate(item['latitude']);
      final longitude = _parseCoordinate(item['longitude']);
      final result = await _attendanceService.checkOut(
        photo: file,
        latitude: latitude,
        longitude: longitude,
        site: sessionUser?.site,
      );

      if (result['success'] == true) {
        await _offlineStorage.removePendingCheckOut(i);
        synced = true;
      } else {
        final message = (result['message'] ?? '').toString().toLowerCase();
        if (message.contains('sudah check-out') || message.contains('already')) {
          await _offlineStorage.removePendingCheckOut(i);
        }
      }
    }

    return synced;
  }

  Future<bool> pauseRealtimeTracking() async {
    if (!_realtimeService.isTracking) {
      return false;
    }
    try {
      await _realtimeService.stopRealtimeTracking();
      return true;
    } catch (e) {
      debugPrint('[AttendanceProvider] Failed to pause tracking: $e');
      return false;
    }
  }

  Future<void> syncRealtimeTracking() async {
    if (_realtimeService.isTracking) {
      return;
    }

    final today = todayAttendance;
    if (today == null || today.checkIn == null || today.checkOut != null) {
      return;
    }

    final user = await _authService.getCurrentUser();
    if (user == null) {
      return;
    }

    DateTime checkInDate;
    try {
      checkInDate = DateTime.parse(today.date);
    } catch (_) {
      checkInDate = DateTime.now();
    }

    final attendanceId = today.id.isNotEmpty
        ? today.id
        : 'temp-${user.id}-${DateTime.now().millisecondsSinceEpoch}';

    try {
      await _realtimeService.startRealtimeTracking(
        user: user,
        attendanceId: attendanceId,
        checkInDate: checkInDate,
        intervalSeconds: 10,
      );
    } catch (e) {
      debugPrint('[AttendanceProvider] Failed to resume tracking: $e');
    }
  }

  /// Pastikan background service tetap running untuk location tracking
  Future<void> ensureBackgroundTracking() async {
    // Prevent double initialization
    if (_backgroundTrackingInitialized) {
      debugPrint('[AttendanceProvider] Background tracking already initialized, skipping');
      return;
    }

    final today = todayAttendance;
    if (today == null || today.checkIn == null || today.checkOut != null) {
      debugPrint('[AttendanceProvider] No active attendance, skipping background tracking');
      return;
    }

    try {
      // Pastikan background service running
      await BackgroundTrackingService.ensureRunning();
      _backgroundTrackingInitialized = true;
      debugPrint('[AttendanceProvider] ✓ Background tracking service initialized');
    } catch (e) {
      debugPrint('[AttendanceProvider] Failed to ensure background tracking: $e');
    }
  }
}
