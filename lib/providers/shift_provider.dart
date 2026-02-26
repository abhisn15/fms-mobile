import 'package:flutter/foundation.dart';
import '../models/shift_model.dart';
import '../services/attendance_service.dart';
import '../utils/error_handler.dart';

class ShiftProvider with ChangeNotifier {
  final AttendanceService _attendanceService = AttendanceService();
  ShiftSchedulePayload? _shiftData;
  bool _isLoading = false;
  String? _error;
  bool _loadShiftsInProgress = false;

  ShiftSchedulePayload? get shiftData => _shiftData;
  List<DailyShift> get todayShifts => _shiftData?.today ?? [];
  DailyShift? get todayShift =>
      todayShifts.length == 1 ? todayShifts.first : null;
  List<DailyShift> get shifts => _shiftData?.upcoming ?? [];
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadShifts() async {
    if (_loadShiftsInProgress) {
      debugPrint('[ShiftProvider] loadShifts skipped: request already running');
      return;
    }
    _loadShiftsInProgress = true;
    debugPrint('[ShiftProvider] Loading shift schedule...');
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _shiftData = await _attendanceService.getShiftSchedule();
      _error = null;
      debugPrint('[ShiftProvider] ✓ Shift schedule loaded successfully');
      if (_shiftData?.today != null && _shiftData!.today.isNotEmpty) {
        final labels = _shiftData!.today
            .map(
              (shift) => '${shift.name} (${shift.startTime}-${shift.endTime})',
            )
            .join(', ');
        debugPrint('[ShiftProvider] Today shifts: $labels');
      }
      debugPrint(
        '[ShiftProvider] Upcoming shifts: ${_shiftData?.upcoming.length ?? 0}',
      );
    } catch (e) {
      _error = ErrorHandler.getErrorMessage(e);
      _shiftData = null;
      debugPrint('[ShiftProvider] ✗ Error loading shifts: $_error');
    } finally {
      _isLoading = false;
      _loadShiftsInProgress = false;
      notifyListeners();
    }
  }
}
