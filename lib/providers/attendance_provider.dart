import 'package:flutter/foundation.dart';
import 'dart:io';
import '../models/attendance_model.dart';
import '../models/user_model.dart';
import '../services/attendance_service.dart';
import '../services/realtime_location_service.dart';
import '../services/offline_storage_service.dart';
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

  AttendancePayload? get attendanceData => _attendanceData;
  AttendanceRecord? get todayAttendance => _attendanceData?.today;
  List<AttendanceRecord> get recentAttendance => _attendanceData?.recent ?? [];
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isOfflineMode => _isOfflineMode;
  bool get isRealtimeTracking => _realtimeService.isTracking;

  void setConnectivityProvider(ConnectivityProvider provider) {
    _connectivityProvider = provider;
  }

  Future<void> loadAttendance({DateTime? startDate, DateTime? endDate, bool forceRefresh = false}) async {
    debugPrint('[AttendanceProvider] Loading attendance... (forceRefresh: $forceRefresh)');
    
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
      notifyListeners();
    }
  }

  Future<bool> checkIn({required File photo, String? shiftId}) async {
    debugPrint('[AttendanceProvider] Check-in initiated');
    debugPrint('[AttendanceProvider] Shift ID: ${shiftId ?? "null (no shift)"}');
    _isLoading = true;
    _error = null;
    notifyListeners();

    final isConnected = _connectivityProvider?.isConnected ?? true;

    try {
      if (isConnected) {
        // Try to check-in online
        try {
          final result = await _attendanceService.checkIn(
            photo: photo,
            shiftId: shiftId, // Opsional - bisa null
          );

          if (result['success'] == true) {
            debugPrint('[AttendanceProvider] ✓ Check-in successful, reloading attendance...');
            // Reset loading sebelum loadAttendance untuk menghindari loading state yang stuck
            _isLoading = false;
            notifyListeners();
            // Load attendance dengan forceRefresh untuk mendapatkan data terbaru
            final now = DateTime.now();
            final startDate = DateTime(now.year, now.month, 1);
            await loadAttendance(
              startDate: startDate,
              endDate: now,
              forceRefresh: true,
            );

            // Start realtime location tracking setelah check-in berhasil
            try {
              debugPrint('[AttendanceProvider] Starting realtime location tracking...');
              final user = await _authService.getCurrentUser();
              debugPrint('[AttendanceProvider] Current user: ${user?.name} (${user?.id})');

              // Wait a bit for attendance data to be updated
              await Future.delayed(const Duration(milliseconds: 500));

              final todayRecord = todayAttendance;
              debugPrint('[AttendanceProvider] Today attendance: ${todayRecord?.checkIn} - ${todayRecord?.checkOut}, ID: ${todayRecord?.id}');

              if (user != null && todayRecord != null) {
                debugPrint('[AttendanceProvider] ✅ User and attendance record available');

                // Use attendance ID if available, otherwise use a temporary ID
                final attendanceId = todayRecord.id.isNotEmpty ? todayRecord.id : 'temp-${user.id}-${now.millisecondsSinceEpoch}';
                debugPrint('[AttendanceProvider] Using attendance ID: $attendanceId');

                // Gunakan interval default 10 detik untuk testing
                await _realtimeService.startRealtimeTracking(
                  user: user,
                  attendanceId: attendanceId,
                  checkInDate: now,
                  intervalSeconds: 10,
                );
                debugPrint('[AttendanceProvider] ✓ Realtime tracking started successfully');
              } else {
                debugPrint('[AttendanceProvider] ❌ Cannot start tracking: user=${user != null}, todayRecord=${todayRecord != null}');
              }
            } catch (e) {
              debugPrint('[AttendanceProvider] ❌ Failed to start realtime tracking: $e');
              debugPrint('[AttendanceProvider] Stack trace: ${e.toString()}');
              // Don't fail check-in just because tracking failed
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
      notifyListeners();
    }
  }

  Future<bool> checkOut({required File photo}) async {
    debugPrint('[AttendanceProvider] Check-out initiated');
    _isLoading = true;
    _error = null;
    notifyListeners();

    final isConnected = _connectivityProvider?.isConnected ?? true;

    try {
      if (isConnected) {
        // Try to check-out online
        try {
          final result = await _attendanceService.checkOut(photo: photo);

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
      notifyListeners();
    }
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
}
