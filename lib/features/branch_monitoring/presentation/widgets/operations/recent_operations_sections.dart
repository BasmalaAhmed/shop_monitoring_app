import 'package:flutter/material.dart';
import 'package:shop_monitoring_app/core/theme/app_colors.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/domain/entities/recent_operation.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/presentation/widgets/header/section_header.dart';
import 'operation_item.dart';

class RecentOperationsSection extends StatelessWidget {
  const RecentOperationsSection({super.key, required this.operations});

  final List<RecentOperation> operations;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(
              title: 'آخر العمليات',
              subtitle: 'أحدث حركات المبيعات في المتجر',
            ),
            const SizedBox(height: 12),
            if (operations.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'لا توجد عمليات حتى الآن',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                ),
              )
            else
              ...operations
                  .take(10)
                  .map(
                    (operation) => Column(
                      children: [
                        OperationItem(operation: operation),
                        if (operation != operations.take(10).last)
                          const Divider(height: 1),
                      ],
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
