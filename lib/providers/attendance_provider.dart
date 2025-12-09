import 'package:flutter/foundation.dart';
import 'dart:io';
import '../models/attendance_model.dart';
import '../services/attendance_service.dart';
import '../services/offline_storage_service.dart';
import '../utils/error_handler.dart';
import 'connectivity_provider.dart';

class AttendanceProvider with ChangeNotifier {
  final AttendanceService _attendanceService = AttendanceService();
  final OfflineStorageService _offlineStorage = OfflineStorageService();
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

  Future<bool> checkIn({required File photo, required String shiftId}) async {
    debugPrint('[AttendanceProvider] Check-in initiated');
    debugPrint('[AttendanceProvider] Shift ID: $shiftId');
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
            shiftId: shiftId,
          );

          if (result['success'] == true) {
            debugPrint('[AttendanceProvider] ✓ Check-in successful, reloading attendance...');
            await loadAttendance();
            return true;
          } else {
            _error = result['message'] as String? ?? 'Check-in gagal';
            debugPrint('[AttendanceProvider] ✗ Check-in failed: $_error');
            return false;
          }
        } catch (e) {
          // If online check-in fails, save to pending
          debugPrint('[AttendanceProvider] ⚠ Online check-in failed, saving to pending...');
          await _offlineStorage.savePendingCheckIn({
            'photo': photo.path,
            'shiftId': shiftId,
          });
          _error = 'Check-in disimpan untuk sync nanti';
          debugPrint('[AttendanceProvider] ✓ Check-in saved to pending');
          return true;
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
            await loadAttendance();
            return true;
          } else {
            _error = result['message'] as String? ?? 'Check-out gagal';
            debugPrint('[AttendanceProvider] ✗ Check-out failed: $_error');
            return false;
          }
        } catch (e) {
          // If online check-out fails, save to pending
          debugPrint('[AttendanceProvider] ⚠ Online check-out failed, saving to pending...');
          await _offlineStorage.savePendingCheckOut({
            'photo': photo.path,
          });
          _error = 'Check-out disimpan untuk sync nanti';
          debugPrint('[AttendanceProvider] ✓ Check-out saved to pending');
          return true;
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
}

