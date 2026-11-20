import 'dart:async';

import 'package:shop_monitoring_app/features/branch_monitoring/data/datasources/connectivity_service.dart';

class MockConnectivityService implements ConnectivityService {
  final StreamController<bool> _controller = StreamController<bool>.broadcast();

  bool _isOnline = true;

  @override
  bool get isOnline => _isOnline;

  @override
  Stream<bool> get changes => _controller.stream;

  void setOnline(bool value) {
    if (_isOnline == value) return;

    _isOnline = value;
    _controller.add(value);
  }

  void dispose() {
    _controller.close();
  }
}
