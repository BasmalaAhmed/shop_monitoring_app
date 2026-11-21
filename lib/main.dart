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
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('النطاق: ${state.selectedScopeId}'),
                DropdownButton<String>(
                  value: state.selectedScopeId,
                  isExpanded: true,
                  hint: const Text('اختاري الفرع'),
                  items: [
                    const DropdownMenuItem(
                      value: 'all',
                      child: Text('كل الفروع'),
                    ),
                    ...state.branches.map(
                      (branch) => DropdownMenuItem(
                        value: branch.id,
                        child: Text(branch.name),
                      ),
                    ),
                  ],
                  onChanged: (scopeId) {
                    if (scopeId != null) {
                      context.read<BranchMonitoringCubit>().selectScope(
                        scopeId,
                      );
                    }
                  },
                ),
                Text('إجمالي المبيعات: ${state.snapshot.summary.totalSales}'),
                Text('إجمالي السيولة: ${state.snapshot.summary.totalCash}'),
                Text('سعر الذهب: ${state.goldPrice?.value ?? "غير متاح"}'),
                Text(state.isOnline ? 'متصل بالإنترنت' : 'غير متصل'),
                if (state.isRefreshing)
                  const Center(child: CircularProgressIndicator()),

                const SizedBox(height: 24),

                const Text(
                  'آخر العمليات',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 12),

                if (state.snapshot.recentOperations.isEmpty)
                  const Center(child: Text('لا توجد عمليات حتى الآن'))
                else
                  ...state.snapshot.recentOperations.map(
                    (operation) => Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.receipt_long),
                        ),
                        title: Text(operation.description),
                        subtitle: Text(
                          operation.createdAt.toLocal().toString(),
                        ),
                        trailing: Text(
                          operation.amount.toString(),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }
}
