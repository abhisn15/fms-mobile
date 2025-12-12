import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../utils/error_handler.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  User? _user;
  bool _isLoading = false;
  String? _error;

  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _user != null;

  AuthProvider() {
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    _isLoading = true;
    notifyListeners();

    try {
      _user = await _authService.getCurrentUser();
      if (_user == null) {
        // Session expired atau tidak valid
        debugPrint('[AuthProvider] Session expired or invalid');
        await logout();
      }
      _error = null;
    } catch (e) {
      debugPrint('[AuthProvider] Error checking auth status: $e');
      _error = ErrorHandler.getErrorMessage(e);
      _user = null;
      // Jika error karena session expired, logout
      if (e.toString().contains('401') || e.toString().contains('403')) {
        await logout();
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _authService.login(email, password);
      if (result['success'] == true) {
        _user = result['user'] as User;
        _error = null;
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = result['message'] as String? ?? 'Login gagal';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = ErrorHandler.getErrorMessage(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    debugPrint('[AuthProvider] Logging out...');
    await _authService.logout();
    _user = null;
    _error = null;
    notifyListeners();
    debugPrint('[AuthProvider] ✓ Logout completed, user cleared');
  }

  void updateUserPhoto(String photoUrl) {
    if (_user != null) {
      _user = User(
        id: _user!.id,
        externalId: _user!.externalId,
        name: _user!.name,
        email: _user!.email,
        role: _user!.role,
        photoUrl: photoUrl,
        team: _user!.team,
        title: _user!.title,
      );
      notifyListeners();
    }
  }

  Future<void> refreshUser() async {
    await _checkAuthStatus();
  }
}

