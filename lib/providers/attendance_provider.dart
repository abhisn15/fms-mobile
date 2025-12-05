import 'package:flutter/foundation.dart';
import 'dart:io';
import '../models/attendance_model.dart';
import '../services/attendance_service.dart';
import '../utils/error_handler.dart';

class AttendanceProvider with ChangeNotifier {
  final AttendanceService _attendanceService = AttendanceService();
  AttendancePayload? _attendanceData;
  bool _isLoading = false;
  String? _error;

  AttendancePayload? get attendanceData => _attendanceData;
  AttendanceRecord? get todayAttendance => _attendanceData?.today;
  List<AttendanceRecord> get recentAttendance => _attendanceData?.recent ?? [];
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadAttendance() async {
    debugPrint('[AttendanceProvider] Loading attendance...');
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _attendanceData = await _attendanceService.getAttendance();
      _error = null;
      debugPrint('[AttendanceProvider] ✓ Attendance loaded successfully');
      if (_attendanceData?.today != null) {
        debugPrint('[AttendanceProvider] Today: ${_attendanceData!.today!.checkIn} - ${_attendanceData!.today!.checkOut}');
      }
    } catch (e) {
      _error = ErrorHandler.getErrorMessage(e);
      _attendanceData = null;
      debugPrint('[AttendanceProvider] ✗ Error loading attendance: $_error');
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

