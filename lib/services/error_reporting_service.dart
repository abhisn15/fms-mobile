import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../config/api_config.dart';
import 'api_service.dart';

class ErrorReportingService {
  static final ErrorReportingService _instance = ErrorReportingService._internal();
  factory ErrorReportingService() => _instance;
  ErrorReportingService._internal();

  final ApiService _apiService = ApiService();
  final List<Map<String, dynamic>> _queue = [];
  bool _isSending = false;
  DateTime? _lastSentAt;

  void reportFlutterError(FlutterErrorDetails details, {bool isFatal = false}) {
    reportError(
      details.exception,
      details.stack,
      isFatal: isFatal,
      context: {
        'library': details.library,
        'context': details.context?.toDescription(),
        'silent': details.silent,
      },
    );
  }

  void reportError(
    Object error,
    StackTrace? stack, {
    bool isFatal = false,
    Map<String, dynamic>? context,
  }) {
    final payload = _buildPayload(
      message: error.toString(),
      stack: stack?.toString(),
      isFatal: isFatal,
      context: context,
    );
    _enqueue(payload);
  }

  Map<String, dynamic> _buildPayload({
    required String message,
    String? stack,
    bool isFatal = false,
    Map<String, dynamic>? context,
  }) {
    final trimmedMessage = _truncate(message, 2000);
    final trimmedStack = stack != null ? _truncate(stack, 8000) : null;

    return {
      'message': trimmedMessage,
      if (trimmedStack != null) 'stack': trimmedStack,
      'isFatal': isFatal,
      'platform': Platform.operatingSystem,
      'platformVersion': Platform.operatingSystemVersion,
      'timestamp': DateTime.now().toIso8601String(),
      if (context != null) 'context': context,
      if (kDebugMode) 'debugMode': true,
    };
  }

  void _enqueue(Map<String, dynamic> payload) {
    if (_queue.length >= 10) {
      _queue.removeAt(0);
    }
    _queue.add(payload);
    _flush();
  }

  void _flush() {
    if (_isSending || _queue.isEmpty) return;

    final now = DateTime.now();
    if (_lastSentAt != null && now.difference(_lastSentAt!) < const Duration(seconds: 5)) {
      Future.delayed(const Duration(seconds: 5), _flush);
      return;
    }

    _isSending = true;
    final payload = _queue.removeAt(0);

    () async {
      try {
        await _apiService.post(ApiConfig.clientErrorLog, data: payload);
        _lastSentAt = DateTime.now();
      } catch (_) {
        if (_queue.length < 10) {
          _queue.insert(0, payload);
        }
      } finally {
        _isSending = false;
        if (_queue.isNotEmpty) {
          Future.delayed(const Duration(seconds: 2), _flush);
        }
      }
    }();
  }

  String _truncate(String value, int maxLength) {
    if (value.length <= maxLength) return value;
    return value.substring(0, maxLength);
  }
}
