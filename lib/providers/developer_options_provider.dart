import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class DeveloperOptionsProvider with ChangeNotifier {
  static const MethodChannel _channel = MethodChannel('com.atenim.fms/developer_options');

  bool _isDeveloperOptionsEnabled = false;
  bool _isMockLocationEnabled = false;

  bool get isDeveloperOptionsEnabled => _isDeveloperOptionsEnabled;
  bool get isMockLocationEnabled => _isMockLocationEnabled;
  // Hanya check mock location sebagai security risk, developer options boleh aktif
  bool get isSecurityRisk => _isMockLocationEnabled;

  DeveloperOptionsProvider() {
    refreshStatus();
  }

  Future<void> refreshStatus() async {
    try {
      // Check developer options from native Android
      final devOptionsEnabled = await _channel.invokeMethod<bool>('isDeveloperOptionsEnabled') ?? false;
      final mockLocationEnabled = await _channel.invokeMethod<bool>('isMockLocationEnabled') ?? false;
      
      debugPrint('[DeveloperOptionsProvider] Refresh status - Dev options: $devOptionsEnabled, Mock location: $mockLocationEnabled');
      debugPrint('[DeveloperOptionsProvider] Previous status - Dev options: $_isDeveloperOptionsEnabled, Mock location: $_isMockLocationEnabled');
      
      // Selalu update dan notify jika ada perubahan
      bool hasChanged = false;
      if (_isDeveloperOptionsEnabled != devOptionsEnabled) {
        _isDeveloperOptionsEnabled = devOptionsEnabled;
        hasChanged = true;
        debugPrint('[DeveloperOptionsProvider] Developer options changed: $devOptionsEnabled');
      }
      if (_isMockLocationEnabled != mockLocationEnabled) {
        _isMockLocationEnabled = mockLocationEnabled;
        hasChanged = true;
        debugPrint('[DeveloperOptionsProvider] Mock location changed: $mockLocationEnabled');
      }
      
      if (hasChanged) {
        debugPrint('[DeveloperOptionsProvider] Status changed, notifying listeners. Security risk: ${isSecurityRisk}');
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[DeveloperOptionsProvider] Error checking developer options/mock location: $e');
      debugPrint('[DeveloperOptionsProvider] Error details: ${e.toString()}');
      // On error, assume false for security
      if (_isDeveloperOptionsEnabled || _isMockLocationEnabled) {
        debugPrint('[DeveloperOptionsProvider] Error occurred, resetting to false');
        _isDeveloperOptionsEnabled = false;
        _isMockLocationEnabled = false;
        notifyListeners();
      }
    }
  }

  Future<void> openDeveloperOptions() async {
    try {
      await _channel.invokeMethod('openDeveloperOptions');
    } catch (e) {
      debugPrint('Error opening developer options: $e');
    }
  }
}











