import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeveloperOptionsProvider with ChangeNotifier {
  static const String _developerOptionsKey = 'developer_options_enabled';

  bool _isDeveloperOptionsEnabled = false;

  bool get isDeveloperOptionsEnabled => _isDeveloperOptionsEnabled;

  DeveloperOptionsProvider() {
    _loadDeveloperOptionsState();
  }

  Future<void> _loadDeveloperOptionsState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isDeveloperOptionsEnabled = prefs.getBool(_developerOptionsKey) ?? false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading developer options state: $e');
    }
  }

  Future<void> setDeveloperOptionsEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_developerOptionsKey, enabled);
      _isDeveloperOptionsEnabled = enabled;
      notifyListeners();
    } catch (e) {
      debugPrint('Error saving developer options state: $e');
    }
  }

  Future<void> toggleDeveloperOptions() async {
    await setDeveloperOptionsEnabled(!_isDeveloperOptionsEnabled);
  }

  Future<void> refreshStatus() async {
    await _loadDeveloperOptionsState();
  }
}
