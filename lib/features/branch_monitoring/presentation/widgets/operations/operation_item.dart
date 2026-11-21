import 'package:flutter/material.dart';
import 'package:shop_monitoring_app/core/theme/app_colors.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/domain/entities/recent_operation.dart';

class OperationItem extends StatelessWidget {
  const OperationItem({
    super.key,
    required this.operation,
  });

  final RecentOperation operation;

  @override
  Widget build(BuildContext context) {
    final time = operation.createdAt.toLocal();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              color: AppColors.secondary,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  operation.description,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  '${time.day.toString().padLeft(2, '0')}/'
                  '${time.month.toString().padLeft(2, '0')}/'
                  '${time.year} - '
                  '${time.hour.toString().padLeft(2, '0')}:'
                  '${time.minute.toString().padLeft(2, '0')}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${operation.amount} جنيه',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.success,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }
}