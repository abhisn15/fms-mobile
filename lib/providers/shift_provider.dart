import 'package:flutter/foundation.dart';
import '../models/shift_model.dart';
import '../services/attendance_service.dart';
import '../utils/error_handler.dart';

class ShiftProvider with ChangeNotifier {
  final AttendanceService _attendanceService = AttendanceService();
  ShiftSchedulePayload? _shiftData;
  bool _isLoading = false;
  String? _error;

  ShiftSchedulePayload? get shiftData => _shiftData;
  DailyShift? get todayShift => _shiftData?.today;
  List<DailyShift> get shifts => _shiftData?.upcoming ?? [];
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadShifts() async {
    debugPrint('[ShiftProvider] Loading shift schedule...');
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _shiftData = await _attendanceService.getShiftSchedule();
      _error = null;
      debugPrint('[ShiftProvider] ✓ Shift schedule loaded successfully');
      if (_shiftData?.today != null) {
        debugPrint('[ShiftProvider] Today shift: ${_shiftData!.today!.name} (${_shiftData!.today!.startTime} - ${_shiftData!.today!.endTime})');
      }
      debugPrint('[ShiftProvider] Upcoming shifts: ${_shiftData?.upcoming.length ?? 0}');
    } catch (e) {
      _error = ErrorHandler.getErrorMessage(e);
      _shiftData = null;
      debugPrint('[ShiftProvider] ✗ Error loading shifts: $_error');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

