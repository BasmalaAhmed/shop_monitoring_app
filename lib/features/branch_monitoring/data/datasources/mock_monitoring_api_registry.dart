import 'package:shop_monitoring_app/features/branch_monitoring/data/datasources/connectivity_service.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/data/datasources/mock_monitoring_api.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/data/models/branch_model.dart';

class MockMonitoringApiRegistry {
  MockMonitoringApiRegistry({required this.connectivity});

  final ConnectivityService connectivity;

  final Map<String, MockMonitoringApi> _apis = {};

  static const Map<String, List<BranchModel>> _branchesByAccount = {
    'demo_shop': MockMonitoringApi.defaultBranches,
    'shop_2': [
      BranchModel(id: 'b1', name: 'فرع طنطا'),
      BranchModel(id: 'b2', name: 'فرع أسوان'),
    ],
  };

  MockMonitoringApi forAccount(String accountId) {
    return _apis.putIfAbsent(accountId, () {
      final api = MockMonitoringApi(
        connectivity: connectivity,
        branches: _branchesByAccount[accountId],
      );

      api.startSimulation();

      return api;
    });
  }

  void dispose() {
    for (final api in _apis.values) {
      api.dispose();
    }

    _apis.clear();
  }
}
