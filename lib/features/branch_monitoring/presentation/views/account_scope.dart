import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shop_monitoring_app/core/session/account_session.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/presentation/manager/cubits/branch_monitoring_cubit/branch_monitoring_cubit.dart';

class AccountScope extends StatelessWidget {
  const AccountScope({
    super.key,
    required this.session,
    required this.createCubit,
    required this.builder,
  });

  final AccountSession session;
  final BranchMonitoringCubit Function(String accountId) createCubit;
  final Widget Function(BuildContext context, String accountId) builder;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: session,
      builder: (context, accountId, _) {
        return BlocProvider(
          key: ValueKey(accountId),
          create: (_) => createCubit(accountId)..load(),
          child: Builder(
            builder: (context) => builder(context, accountId),
          ),
        );
      },
    );
  }
}