import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shop_monitoring_app/core/lifecycle/app_lifecycle_observer.dart';
import 'package:shop_monitoring_app/core/service_locator.dart';
import 'package:shop_monitoring_app/core/session/account_manager.dart';
import 'package:shop_monitoring_app/core/session/account_session.dart';
import 'package:shop_monitoring_app/core/theme/app_theme.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/presentation/manager/cubits/branch_monitoring_cubit/branch_monitoring_cubit.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/presentation/views/account_scope.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/presentation/views/branch_monitoring_view.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await setupDependencies();

  runApp(const ShopMonitoringApp());
}

class ShopMonitoringApp extends StatelessWidget {
  const ShopMonitoringApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Shop Monitoring',
      theme: AppTheme.lightTheme,
      locale: const Locale('ar'),
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('ar')],
      home: AccountScope(
        session: getIt<AccountSession>(),
        createCubit: createBranchMonitoringCubit,
        builder: (context, accountId) {
          return AppLifecycleObserver(
            onResumed: () {
              context.read<BranchMonitoringCubit>().refresh();
            },
            child: BranchMonitoringView(
              onSwitchAccount: () {
                getIt<AccountManager>().switchTo(
                  accountId == AccountSession.defaultAccountId
                      ? 'shop_2'
                      : AccountSession.defaultAccountId,
                );
              },
            ),
          );
        },
      ),
    );
  }
}
