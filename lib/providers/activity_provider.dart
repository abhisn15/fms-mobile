import 'package:flutter/foundation.dart';
import 'dart:io';
import '../models/activity_model.dart';
import '../services/activity_service.dart';
import '../utils/error_handler.dart';

class ActivityProvider with ChangeNotifier {
  final ActivityService _activityService = ActivityService();
  ActivityPayload? _activityData;
  bool _isLoading = false;
  String? _error;

  ActivityPayload? get activityData => _activityData;
  DailyActivity? get todayActivity => _activityData?.today;
  List<DailyActivity> get recentActivities => _activityData?.recent ?? [];
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadActivities() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      debugPrint('[ActivityProvider] Loading activities...');
      _activityData = await _activityService.getActivities();
      _error = null;
      debugPrint('[ActivityProvider] ✓ Activities loaded: today=${_activityData?.today != null}, recent=${_activityData?.recent.length ?? 0}');
    } catch (e) {
      _error = ErrorHandler.getErrorMessage(e);
      _activityData = null;
      debugPrint('[ActivityProvider] ✗ Failed to load activities: $_error');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> submitDailyActivity({
    required String summary,
    String? sentiment,
    int? focusHours,
    List<String>? blockers,
    List<String>? highlights,
    List<String>? plans,
    String? notes,
    List<File>? photos,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _activityService.submitDailyActivity(
        summary: summary,
        sentiment: sentiment,
        focusHours: focusHours,
        blockers: blockers,
        highlights: highlights,
        plans: plans,
        notes: notes,
        photos: photos ?? [],
      );

      if (result['success'] == true) {
        await loadActivities();
        return true;
      } else {
        _error = result['message'] as String? ?? 'Operasi gagal';
        return false;
      }
    } catch (e) {
      _error = ErrorHandler.getErrorMessage(e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> submitPatroli({
    required String summary,
    String? notes,
    List<File>? photos,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _activityService.submitPatroli(
        summary: summary,
        notes: notes,
        photos: photos ?? [],
      );

      if (result['success'] == true) {
        await loadActivities();
        return true;
      } else {
        _error = result['message'] as String? ?? 'Operasi gagal';
        return false;
      }
    } catch (e) {
      _error = ErrorHandler.getErrorMessage(e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<DailyActivity?> getActivityById(String id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      debugPrint('[ActivityProvider] Getting activity: $id');
      final result = await _activityService.getActivityById(id);
      if (result['success'] == true) {
        final data = result['data'] as Map<String, dynamic>;
        final activity = DailyActivity.fromJson(data);
        debugPrint('[ActivityProvider] ✓ Activity loaded');
        return activity;
      } else {
        _error = result['message'] as String;
        return null;
      }
    } catch (e) {
      _error = ErrorHandler.getErrorMessage(e);
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateActivity({
    required String id,
    required String summary,
    String? sentiment,
    int? focusHours,
    List<String>? blockers,
    List<String>? highlights,
    List<String>? plans,
    String? notes,
    List<File>? newPhotos,
    List<String>? existingPhotoUrls,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      debugPrint('[ActivityProvider] Updating activity: $id');
      final result = await _activityService.updateActivity(
        id: id,
        summary: summary,
        sentiment: sentiment,
        focusHours: focusHours,
        blockers: blockers,
        highlights: highlights,
        plans: plans,
        notes: notes,
        newPhotos: newPhotos ?? [],
        existingPhotoUrls: existingPhotoUrls ?? [],
      );

      if (result['success'] == true) {
        await loadActivities();
        debugPrint('[ActivityProvider] ✓ Activity updated');
        return true;
      } else {
        _error = result['message'] as String? ?? 'Operasi gagal';
        return false;
      }
    } catch (e) {
      _error = ErrorHandler.getErrorMessage(e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteActivity(String id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      debugPrint('[ActivityProvider] Deleting activity: $id');
      final result = await _activityService.deleteActivity(id);
      if (result['success'] == true) {
        await loadActivities();
        debugPrint('[ActivityProvider] ✓ Activity deleted');
        return true;
      } else {
        _error = result['message'] as String? ?? 'Operasi gagal';
        return false;
      }
    } catch (e) {
      _error = ErrorHandler.getErrorMessage(e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
