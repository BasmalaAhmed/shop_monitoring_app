import 'package:flutter/material.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/domain/entities/branch.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/presentation/widgets/common/connection_status.dart';
import 'branch_selector.dart';
import 'dashboard_header.dart';

class DashboardHeaderSection extends StatelessWidget {
  const DashboardHeaderSection({
    super.key,
    required this.isOnline,
    required this.branches,
    required this.selectedScopeId,
    required this.onBranchChanged,
  });

  final bool isOnline;
  final List<Branch> branches;
  final String selectedScopeId;
  final ValueChanged<String> onBranchChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
              child: DashboardHeader(),
            ),
            const SizedBox(width: 12),
            ConnectionStatus(isOnline: isOnline),
          ],
        ),
        const SizedBox(height: 20),
        BranchSelector(
          branches: branches,
          selectedScopeId: selectedScopeId,
          onChanged: onBranchChanged,
        ),
      ],
    );
  }
}