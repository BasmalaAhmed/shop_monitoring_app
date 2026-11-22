import 'package:flutter/material.dart';
import 'package:shop_monitoring_app/core/theme/app_colors.dart';
import 'package:shop_monitoring_app/core/utils/date_time_formatter.dart';

class GoldPriceCard extends StatelessWidget {
  const GoldPriceCard({
    super.key,
    required this.price,
    required this.updatedAt,
  });

  final int? price;
  final DateTime? updatedAt;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF164E63), Color(0xFF0F766E)],
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.currency_exchange_rounded,
              color: AppColors.gold,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'سعر الذهب لعيار 21',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 6),
                Text(
                  price == null ? 'غير متاح' : '$price جنيه',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (updatedAt != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'آخر تحديث: ${DateTimeFormatter.time(updatedAt!)}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          const Icon(Icons.auto_graph_rounded, color: AppColors.gold, size: 30),
        ],
      ),
    );
  }
}
