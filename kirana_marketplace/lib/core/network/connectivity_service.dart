import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Thin wrapper around connectivity_plus exposed as a ChangeNotifier so
/// widgets can watch `isOnline` directly via Provider, and repositories
/// can do a cheap synchronous-ish check before attempting a network call
/// (e.g. sending an OTP SMS via textbee.dev).
///
/// Note: connectivity does not guarantee actual internet reachability
/// (e.g. connected to Wi-Fi with no internet), just that a network
/// interface is up. It's a reasonable, cheap first line of defense --
/// real network calls still need their own timeout/error handling on top
/// (see AuthRepository.sendOtp).
class ConnectivityService extends ChangeNotifier {
  final Connectivity _connectivity;
  bool _isOnline = true;
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  ConnectivityService({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity() {
    _init();
  }

  bool get isOnline => _isOnline;

  Future<void> _init() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _isOnline = _resultIndicatesOnline(result);
      notifyListeners();
    } catch (_) {
      // If the platform check itself fails, assume online rather than
      // permanently locking the user out of network features.
      _isOnline = true;
    }

    _subscription =
        _connectivity.onConnectivityChanged.listen((result) {
      final online = _resultIndicatesOnline(result);
      if (online != _isOnline) {
        _isOnline = online;
        notifyListeners();
      }
    });
  }

  bool _resultIndicatesOnline(List<ConnectivityResult> results) {
    return results.any((r) => r != ConnectivityResult.none);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
