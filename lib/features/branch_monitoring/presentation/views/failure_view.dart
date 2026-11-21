import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/presentation/manager/cubits/branch_monitoring_cubit/branch_monitoring_cubit.dart';

class FailureView extends StatelessWidget {
  final bool canGoBack;

  const FailureView({super.key, required this.canGoBack});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<BranchMonitoringCubit>();

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 48),
            const SizedBox(height: 16),
            const Text(
              'حدث خطأ أثناء تحميل البيانات',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: cubit.retryFromFailure,
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
            ),
            if (canGoBack) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: cubit.backFromFailure,
                child: const Text('رجوع'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
