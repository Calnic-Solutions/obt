import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

/// Whether the phone has a network at all - Wi-Fi, mobile data, a cable.
///
/// Only for what the screen offers. Nothing is sent or fetched because a
/// network has appeared: that is still the user's to ask for. This is what
/// lets the workbench not offer a send the phone has no way to make.
///
/// It is the phone's own word for it, not a request to the server, so it
/// costs nothing to keep listening - and it says "there is a network", not
/// "the server can be reached". The send asks that for itself.
class NetworkWatch {
  NetworkWatch._();

  /// True until the phone says otherwise: a phone that cannot be asked is
  /// not treated as one that is offline.
  static final RxBool online = true.obs;

  static StreamSubscription<List<ConnectivityResult>>? _changes;

  static Future<void> start() async {
    if (_changes != null) return;

    try {
      final connectivity = Connectivity();
      _changes = connectivity.onConnectivityChanged.listen(
        _read,
        onError: (Object e) => debugPrint('NETWORK WATCH ERROR: $e'),
      );
      _read(await connectivity.checkConnectivity());
    } catch (e) {
      debugPrint('NETWORK WATCH UNAVAILABLE: $e');
    }
  }

  static void _read(List<ConnectivityResult> networks) {
    online.value = hasNetwork(networks);
  }

  /// Whether any of [networks] can carry a request. Bluetooth is a
  /// connection to a headset, not to the internet.
  @visibleForTesting
  static bool hasNetwork(List<ConnectivityResult> networks) => networks.any(
    (network) =>
        network != ConnectivityResult.none &&
        network != ConnectivityResult.bluetooth,
  );
}
