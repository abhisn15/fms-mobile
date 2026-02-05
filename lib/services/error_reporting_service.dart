import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../config/api_config.dart';
import 'auth_service.dart';
import 'api_service.dart';

class ErrorReportingService {
  static final ErrorReportingService _instance = ErrorReportingService._internal();
  factory ErrorReportingService() => _instance;
  ErrorReportingService._internal() {
    _warmContext();
  }

  final ApiService _apiService = ApiService();
  final List<Map<String, dynamic>> _queue = [];
  bool _isSending = false;
  DateTime? _lastSentAt;
  Map<String, dynamic>? _deviceContext;
  Map<String, dynamic>? _appContext;
  Map<String, dynamic>? _userContext;
  bool _isContextLoading = false;

  void reportFlutterError(FlutterErrorDetails details, {bool isFatal = false}) {
    _warmContext();
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
    _warmContext();
    final payload = _buildPayload(
      message: error.toString(),
      stack: stack?.toString(),
      isFatal: isFatal,
      context: context,
    );
    _enqueue(payload);
  }

  void _warmContext() {
    if (_isContextLoading) return;
    if (_deviceContext != null && _appContext != null && _userContext != null) {
      return;
    }
    _isContextLoading = true;
    () async {
      try {
        _deviceContext ??= await _loadDeviceContext();
        _appContext ??= await _loadAppContext();
        _userContext ??= await _loadUserContext();
      } catch (_) {
        // Ignore context loading errors to avoid breaking error reporting.
      } finally {
        _isContextLoading = false;
      }
    }();
  }

  Future<Map<String, dynamic>> _loadDeviceContext() async {
    final deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final info = await deviceInfo.androidInfo;
      return {
        'platform': 'android',
        'brand': info.brand,
        'model': info.model,
        'device': info.device,
        'manufacturer': info.manufacturer,
        'version': info.version.release,
        'sdkInt': info.version.sdkInt,
        'isPhysicalDevice': info.isPhysicalDevice,
      };
    }
    if (Platform.isIOS) {
      final info = await deviceInfo.iosInfo;
      return {
        'platform': 'ios',
        'name': info.name,
        'model': info.model,
        'systemName': info.systemName,
        'systemVersion': info.systemVersion,
        'isPhysicalDevice': info.isPhysicalDevice,
      };
    }
    return {
      'platform': Platform.operatingSystem,
      'version': Platform.operatingSystemVersion,
    };
  }

  Future<Map<String, dynamic>> _loadAppContext() async {
    final info = await PackageInfo.fromPlatform();
    return {
      'name': info.appName,
      'package': info.packageName,
      'version': info.version,
      'buildNumber': info.buildNumber,
    };
  }

  Future<Map<String, dynamic>?> _loadUserContext() async {
    try {
      final user = await AuthService().getCachedUserOnly();
      if (user == null) {
        return null;
      }
      return {
        'id': user.id,
        'email': user.email,
        'name': user.name,
      };
    } catch (_) {
      return null;
    }
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
      if (_deviceContext != null) 'device': _deviceContext,
      if (_appContext != null) 'app': _appContext,
      if (_userContext != null) 'user': _userContext,
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
