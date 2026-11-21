import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/presentation/manager/cubits/branch_monitoring_cubit/branch_monitoring_cubit.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/presentation/manager/cubits/branch_monitoring_cubit/branch_monitoring_state.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/presentation/widgets/header/dashboard_header_section.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/presentation/widgets/operations/recent_operations_sections.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/presentation/widgets/summary/gold_price_card.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/presentation/widgets/summary/summary_grid.dart';

class BranchMonitoringView extends StatelessWidget {
  const BranchMonitoringView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: BlocBuilder<BranchMonitoringCubit, BranchMonitoringState>(
          builder: (context, state) {
            if (state is BranchMonitoringInitial ||
                state is BranchMonitoringLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state is BranchMonitoringFailure) {
              return const Center(child: Text('حدث خطأ أثناء تحميل البيانات'));
            }

            if (state is BranchMonitoringSuccess) {
              return RefreshIndicator(
                onRefresh: () {
                  return context.read<BranchMonitoringCubit>().refresh();
                },
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1100),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            DashboardHeaderSection(
                              isOnline: state.isOnline,
                              branches: state.branches,
                              selectedScopeId: state.selectedScopeId,
                              onBranchChanged: (scopeId) {
                                context
                                    .read<BranchMonitoringCubit>()
                                    .selectScope(scopeId);
                              },
                            ),
                            const SizedBox(height: 24),

                            SummaryGrid(
                              totalSales: state.snapshot.summary.totalSales,
                              totalCash: state.snapshot.summary.totalCash,
                            ),
                            const SizedBox(height: 16),

                            GoldPriceCard(
                              price: state.goldPrice?.value,
                              updatedAt: state.goldPrice?.updatedAt,
                            ),
                            const SizedBox(height: 24),

                            RecentOperationsSection(
                              operations: state.snapshot.recentOperations,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }

            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}
