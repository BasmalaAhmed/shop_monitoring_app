import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shop_monitoring_app/core/utils/date_time_formatter.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/presentation/manager/cubits/branch_monitoring_cubit/branch_monitoring_cubit.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/presentation/manager/cubits/branch_monitoring_cubit/branch_monitoring_state.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/presentation/views/failure_view.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/presentation/widgets/header/dashboard_header_section.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/presentation/widgets/operations/recent_operations_sections.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/presentation/widgets/summary/gold_price_card.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/presentation/widgets/summary/summary_grid.dart';

class BranchMonitoringView extends StatelessWidget {
  const BranchMonitoringView({super.key, this.onSwitchAccount});

  final VoidCallback? onSwitchAccount;

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
              return PopScope(
                canPop: state.previous == null,
                onPopInvokedWithResult: (didPop, _) {
                  if (!didPop) {
                    context.read<BranchMonitoringCubit>().backFromFailure();
                  }
                },
                child: FailureView(
                  canGoBack: state.previous != null,
                  isNetworkError: state.isNetworkError,
                ),
              );
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
                              selectedScopeId:
                                  state.loadingScopeId ?? state.selectedScopeId,
                              isLoadingBranch: state.loadingScopeId != null,
                              onSwitchAccount: onSwitchAccount,
                              onBranchChanged: (scopeId) {
                                context
                                    .read<BranchMonitoringCubit>()
                                    .selectScope(scopeId);
                              },
                            ),
                            const SizedBox(height: 16),

                            if (!state.isOnline ||
                                state.snapshot.isFromCache) ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.secondaryContainer,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.cloud_off_outlined,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.surface,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'تعرض آخر البيانات المحفوظة',
                                        style: TextStyle(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.surface,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      'آخر تحديث: ${DateTimeFormatter.timeOrDateTime(state.snapshot.lastDataAt)}',
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.surface,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],

                            AnimatedOpacity(
                              opacity: state.loadingScopeId != null ? 0.5 : 1,
                              duration: const Duration(milliseconds: 150),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  SummaryGrid(
                                    totalSales:
                                        state.snapshot.summary.totalSales,
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
