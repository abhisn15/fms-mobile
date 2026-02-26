import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/request_model.dart';
import '../services/request_service.dart';
import '../utils/error_handler.dart';

class RequestProvider with ChangeNotifier {
  final RequestService _requestService = RequestService();
  RequestPayload? _requestData;
  bool _isLoading = false;
  String? _error;
  bool _loadRequestsInProgress = false;

  RequestPayload? get requestData => _requestData;
  List<LeaveRequest> get requests => _requestData?.requests ?? [];
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadRequests() async {
    if (_loadRequestsInProgress) {
      debugPrint(
        '[RequestProvider] loadRequests skipped: request already running',
      );
      return;
    }
    _loadRequestsInProgress = true;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _requestData = await _requestService.getRequests();
      _error = null;
    } catch (e) {
      _error = ErrorHandler.getErrorMessage(e);
      _requestData = null;
    } finally {
      _isLoading = false;
      _loadRequestsInProgress = false;
      notifyListeners();
    }
  }

  Future<bool> createRequest({
    required String type,
    required String reason,
    required String startDate,
    required String endDate,
    List<File> photos = const [],
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _requestService.createRequest(
        type: type,
        reason: reason,
        startDate: startDate,
        endDate: endDate,
        photos: photos,
      );

      if (result['success'] == true) {
        await loadRequests();
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
