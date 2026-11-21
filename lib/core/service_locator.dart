import 'package:get_it/get_it.dart';
import 'package:shop_monitoring_app/core/network/connectivity_plus_service.dart';
import 'package:shop_monitoring_app/core/network/mock_connectivity_service.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/data/datasources/connectivity_service.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/data/datasources/mock_monitoring_api.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/data/datasources/monitoring_api.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/data/datasources/monitoring_database.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/data/datasources/monitoring_local_data_source.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/data/datasources/sqflite_monitoring_local_data_source.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/data/repos/gold_price_repo_impl.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/data/repos/monitoring_repo_impl.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/domain/repos/gold_price_repo.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/domain/repos/monitoring_repo.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/domain/usecases/monitoring_update_processor.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/presentation/manager/cubits/branch_monitoring_cubit/branch_monitoring_cubit.dart';

final getIt = GetIt.instance;

Future<void> setupDependencies({
  MonitoringDatabase? database,
  ConnectivityService? connectivity,
}) async {
  getIt.registerSingleton<ConnectivityService>(
    connectivity ?? await _createConnectivityService(),
  );

  getIt.registerLazySingleton<MockMonitoringApi>(
    () => MockMonitoringApi(connectivity: getIt<ConnectivityService>()),
  );

  getIt.registerLazySingleton<MonitoringApi>(() => getIt<MockMonitoringApi>());

  getIt.registerLazySingleton<MonitoringDatabase>(
    () => database ?? MonitoringDatabase(),
  );

  getIt.registerLazySingleton<MonitoringLocalDataSource>(
    () => SqfliteMonitoringLocalDataSource(getIt<MonitoringDatabase>()),
  );

  getIt.registerLazySingleton<MonitoringRepo>(
    () => MonitoringRepoImpl(
      getIt<MonitoringApi>(),
      getIt<MonitoringLocalDataSource>(),
    ),
  );

  getIt.registerLazySingleton<GoldPriceRepo>(
    () => GoldPriceRepoImpl(
      getIt<MockMonitoringApi>(),
      getIt<MonitoringLocalDataSource>(),
    ),
  );

  getIt.registerLazySingleton<MonitoringUpdateProcessor>(
    () => const MonitoringUpdateProcessor(),
  );

  getIt.registerFactory<BranchMonitoringCubit>(
    () => BranchMonitoringCubit(
      monitoringRepo: getIt<MonitoringRepo>(),
      goldPriceRepo: getIt<GoldPriceRepo>(),
      connectivity: getIt<ConnectivityService>(),
      updateProcessor: getIt<MonitoringUpdateProcessor>(),
    ),
  );
}

Future<ConnectivityService> _createConnectivityService() async {
  final service = ConnectivityPlusService();
  await service.init();
  return service;
}

void startSimulation() {
  getIt<MockMonitoringApi>().startSimulation();
}

Future<void> disposeDependencies() async {
  getIt<MockMonitoringApi>().dispose();

  final connectivity = getIt<ConnectivityService>();
  if (connectivity is ConnectivityPlusService) {
    await connectivity.dispose();
  } else if (connectivity is MockConnectivityService) {
    connectivity.dispose();
  }

  await getIt.reset();
}
