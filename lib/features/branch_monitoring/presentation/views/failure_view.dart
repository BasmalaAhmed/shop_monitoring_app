import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/presentation/manager/cubits/branch_monitoring_cubit/branch_monitoring_cubit.dart';

class FailureView extends StatelessWidget {
  const FailureView({
    super.key,
    required this.canGoBack,
    this.isNetworkError = false,
  });

  final bool canGoBack;
  final bool isNetworkError;

  String get _message {
    if (!isNetworkError) return 'حدث خطأ أثناء تحميل البيانات';

    return canGoBack
        ? 'لا توجد بيانات محفوظة لهذا الفرع. '
              'تحقق من الاتصال وحاول مرة أخرى'
        : 'لا يوجد اتصال بالإنترنت ولا توجد بيانات محفوظة';
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<BranchMonitoringCubit>();

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isNetworkError
                  ? Icons.cloud_off_outlined
                  : Icons.error_outline_rounded,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(_message, textAlign: TextAlign.center),
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