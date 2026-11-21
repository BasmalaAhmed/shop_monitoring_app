import 'package:flutter/material.dart';
import 'package:shop_monitoring_app/core/theme/app_colors.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/domain/entities/branch.dart';

class BranchSelector extends StatelessWidget {
  const BranchSelector({
    super.key,
    required this.branches,
    required this.selectedScopeId,
    required this.onChanged,
  });

  final List<Branch> branches;
  final String selectedScopeId;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedScopeId,
          isExpanded: true,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: AppColors.primary,
          ),
          hint: const Text('اختار الفرع'),
          items: [
            const DropdownMenuItem(
              value: 'all',
              child: Text('كل الفروع'),
            ),
            ...branches.map(
              (branch) => DropdownMenuItem(
                value: branch.id,
                child: Text(branch.name),
              ),
            ),
          ],
          onChanged: (value) {
            if (value != null) {
              onChanged(value);
            }
          },
        ),
      ),
    );
  }
}