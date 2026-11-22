import 'package:get_it/get_it.dart';
import 'package:shop_monitoring_app/core/network/connectivity_plus_service.dart';
import 'package:shop_monitoring_app/core/session/account_manager.dart';
import 'package:shop_monitoring_app/core/session/account_session.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/data/datasources/connectivity_service.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/data/datasources/mock_monitoring_api_registry.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/data/datasources/monitoring_database.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/data/datasources/monitoring_local_data_source.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/data/datasources/sqflite_monitoring_local_data_source.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/data/repos/gold_price_repo_impl.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/data/repos/monitoring_repo_impl.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/domain/usecases/monitoring_update_processor.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/presentation/manager/cubits/branch_monitoring_cubit/branch_monitoring_cubit.dart';

final getIt = GetIt.instance;

Future<void> setupDependencies({
  MonitoringDatabase? database,
  ConnectivityService? connectivity,
}) async {
  getIt.registerSingleton<AccountSession>(AccountSession());

  getIt.registerSingleton<ConnectivityService>(
    connectivity ?? await _createConnectivityService(),
  );

  getIt.registerLazySingleton<MockMonitoringApiRegistry>(
    () => MockMonitoringApiRegistry(connectivity: getIt<ConnectivityService>()),
  );

  getIt.registerLazySingleton<MonitoringDatabase>(
    () => database ?? MonitoringDatabase(),
  );

  getIt.registerLazySingleton<MonitoringLocalDataSource>(
    () => SqfliteMonitoringLocalDataSource(getIt<MonitoringDatabase>()),
  );

  getIt.registerLazySingleton<AccountManager>(
    () => AccountManager(
      session: getIt<AccountSession>(),
      clearAccountData: (accountId) {
        return getIt<MonitoringLocalDataSource>().clearAccount(
          accountId: accountId,
        );
      },
    ),
  );

  getIt.registerLazySingleton<MonitoringUpdateProcessor>(
    () => const MonitoringUpdateProcessor(),
  );
}

BranchMonitoringCubit createBranchMonitoringCubit(String accountId) {
  final api = getIt<MockMonitoringApiRegistry>().forAccount(accountId);
  final localDataSource = getIt<MonitoringLocalDataSource>();

  return BranchMonitoringCubit(
    monitoringRepo: MonitoringRepoImpl(
      api,
      localDataSource,
      accountId: accountId,
    ),
    goldPriceRepo: GoldPriceRepoImpl(
      api,
      localDataSource,
      accountId: accountId,
    ),
    connectivity: getIt<ConnectivityService>(),
    updateProcessor: getIt<MonitoringUpdateProcessor>(),
  );
}

Future<ConnectivityService> _createConnectivityService() async {
  final service = ConnectivityPlusService();
  await service.init();
  return service;
}

Future<void> disposeDependencies() async {
  getIt<MockMonitoringApiRegistry>().dispose();

  final connectivity = getIt<ConnectivityService>();
  if (connectivity is ConnectivityPlusService) {
    await connectivity.dispose();
  }

  getIt<AccountSession>().dispose();

  await getIt.reset();
}
