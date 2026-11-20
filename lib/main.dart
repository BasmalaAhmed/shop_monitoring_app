import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shop_monitoring_app/core/lifecycle/app_lifecycle_observer.dart';
import 'package:shop_monitoring_app/core/service_locator.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/presentation/manager/cubits/branch_monitoring_cubit/branch_monitoring_cubit.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/presentation/manager/cubits/branch_monitoring_cubit/branch_monitoring_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await setupDependencies();
  startSimulation();

  runApp(const ShopMonitoringApp());
}

class ShopMonitoringApp extends StatelessWidget {
  const ShopMonitoringApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Shop Monitoring',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: BlocProvider(
        create: (_) => getIt<BranchMonitoringCubit>()..load(),
        child: Builder(
          builder: (context) {
            return AppLifecycleObserver(
              onResumed: () {
                context.read<BranchMonitoringCubit>().refresh();
              },
              child: const BranchMonitoringHome(),
            );
          },
        ),
      ),
    );
  }
}

class BranchMonitoringHome extends StatelessWidget {
  const BranchMonitoringHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('مراقبة الفروع')),
      body: BlocBuilder<BranchMonitoringCubit, BranchMonitoringState>(
        builder: (context, state) {
          if (state is BranchMonitoringInitial ||
              state is BranchMonitoringLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is BranchMonitoringFailure) {
            return Center(child: Text(state.errorMessage));
          }

          if (state is BranchMonitoringSuccess) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('النطاق: ${state.selectedScopeId}'),
                  Text('إجمالي المبيعات: ${state.snapshot.summary.totalSales}'),
                  Text('إجمالي السيولة: ${state.snapshot.summary.totalCash}'),
                  Text('سعر الذهب: ${state.goldPrice?.value ?? "غير متاح"}'),
                  Text(state.isOnline ? 'متصل بالإنترنت' : 'غير متصل'),
                  if (state.isRefreshing) const CircularProgressIndicator(),
                ],
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }
}
