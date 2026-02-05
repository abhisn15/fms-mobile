import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityProvider with ChangeNotifier {
  final Connectivity _connectivity = Connectivity();
  bool _isConnected = true;
  List<ConnectivityResult> _connectivityResults = [ConnectivityResult.none];

  bool get isConnected => _isConnected;
  List<ConnectivityResult> get connectivityResults => _connectivityResults;
  ConnectivityResult get connectivityResult => _connectivityResults.isNotEmpty ? _connectivityResults.first : ConnectivityResult.none;

  ConnectivityProvider() {
    _init();
  }

  Future<void> _init() async {
    // Check initial connectivity status
    _connectivityResults = await _connectivity.checkConnectivity();
    _isConnected = !_connectivityResults.contains(ConnectivityResult.none);
    notifyListeners();

    // Listen to connectivity changes
    _connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) {
      _connectivityResults = results;
      _isConnected = !results.contains(ConnectivityResult.none);
      debugPrint('[ConnectivityProvider] Connection status changed: ${_isConnected ? "Connected" : "Disconnected"}');
      notifyListeners();
    });
  }

  Future<void> checkConnectivity() async {
    _connectivityResults = await _connectivity.checkConnectivity();
    _isConnected = !_connectivityResults.contains(ConnectivityResult.none);
    notifyListeners();
  }
}

