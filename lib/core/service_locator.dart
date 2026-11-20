import 'package:get_it/get_it.dart';
import 'package:shop_monitoring_app/core/network/mock_connectivity_service.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/data/datasources/connectivity_service.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/data/datasources/mock_monitoring_api.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/data/datasources/monitoring_api.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/data/repos/gold_price_repo_impl.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/data/repos/monitoring_repo_impl.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/domain/repos/gold_price_repo.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/domain/repos/monitoring_repo.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/domain/usecases/monitoring_update_processor.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/presentation/manager/cubits/branch_monitoring_cubit/branch_monitoring_cubit.dart';

final getIt = GetIt.instance;

Future<void> setupDependencies() async {
  getIt.registerLazySingleton<ConnectivityService>(
    () => MockConnectivityService(),
  );

  getIt.registerLazySingleton<MockMonitoringApi>(
    () => MockMonitoringApi(connectivity: getIt<ConnectivityService>()),
  );

  getIt.registerLazySingleton<MonitoringApi>(() => getIt<MockMonitoringApi>());

  getIt.registerLazySingleton<MonitoringRepo>(
    () => MonitoringRepoImpl(getIt<MonitoringApi>()),
  );

  getIt.registerLazySingleton<GoldPriceRepo>(
    () => GoldPriceRepoImpl(getIt<MockMonitoringApi>()),
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

void startSimulation() {
  getIt<MockMonitoringApi>().startSimulation();
}

Future<void> disposeDependencies() async {
  getIt<MockMonitoringApi>().dispose();

  final connectivity = getIt<ConnectivityService>();
  if (connectivity is MockConnectivityService) {
    connectivity.dispose();
  }

  await getIt.reset();
}
