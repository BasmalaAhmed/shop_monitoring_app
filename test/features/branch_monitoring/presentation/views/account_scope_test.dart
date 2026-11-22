import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shop_monitoring_app/core/session/account_session.dart';
import 'package:shop_monitoring_app/core/theme/app_theme.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/domain/entities/branch.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/domain/entities/branch_summary.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/domain/entities/monitoring_snapshot.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/domain/usecases/monitoring_update_processor.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/presentation/manager/cubits/branch_monitoring_cubit/branch_monitoring_cubit.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/presentation/views/account_scope.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/presentation/views/branch_monitoring_view.dart';

import '../../../../helpers/fake_monitoring_dependencies.dart';

void main() {
  late FakeMonitoringRepo repoA;
  late FakeMonitoringRepo repoB;
  late FakeConnectivityService connectivity;
  late AccountSession session;
  late List<BranchMonitoringCubit> created;
  late List<FakeGoldPriceRepo> goldRepos;

  final now = DateTime.utc(2026, 11, 20);

  const accountASales = 111111;
  const accountBSales = 222222;

  MonitoringSnapshot snapshotFor(String scopeId, int sales, int cash) {
    return MonitoringSnapshot(
      scopeId: scopeId,
      sequence: 0,
      summary: BranchSummary(totalSales: sales, totalCash: cash),
      recentOperations: const [],
      updatedAt: now,
    );
  }

  setUp(() {
    created = [];
    goldRepos = [];

    connectivity = FakeConnectivityService();
    session = AccountSession(initialAccountId: 'A');

    repoA = FakeMonitoringRepo()
      ..branches = const [Branch(id: 'a1', name: 'فرع A')]
      ..snapshots = {'all': snapshotFor('all', accountASales, 11)};

    repoB = FakeMonitoringRepo()
      ..branches = const [Branch(id: 'b1', name: 'فرع B')]
      ..snapshots = {'all': snapshotFor('all', accountBSales, 22)};
  });

  tearDown(() async {
    await repoA.dispose();
    await repoB.dispose();
    await connectivity.dispose();

    for (final gold in goldRepos) {
      await gold.dispose();
    }
  });

  BranchMonitoringCubit createCubit(String accountId) {
    final gold = FakeGoldPriceRepo();
    goldRepos.add(gold);

    final cubit = BranchMonitoringCubit(
      monitoringRepo: accountId == 'A' ? repoA : repoB,
      goldPriceRepo: gold,
      connectivity: connectivity,
      updateProcessor: const MonitoringUpdateProcessor(),
    );

    created.add(cubit);

    return cubit;
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }

  Future<void> pumpScope(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        locale: const Locale('ar'),
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        supportedLocales: const [Locale('ar')],
        home: AccountScope(
          session: session,
          createCubit: createCubit,
          builder: (context, accountId) => const BranchMonitoringView(),
        ),
      ),
    );

    await settle(tester);
  }

  group('AccountScope', () {
    testWidgets('old account data never shows after switching accounts', (
      tester,
    ) async {
      await pumpScope(tester);

      expect(find.text('$accountASales'), findsOneWidget);

      session.switchTo('B');
      await tester.pump();

      expect(find.text('$accountASales'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await settle(tester);

      expect(find.text('$accountBSales'), findsOneWidget);
      expect(find.text('$accountASales'), findsNothing);
    });

    testWidgets('a late response of the old account does not show', (
      tester,
    ) async {
      final lateResponse = Completer<MonitoringSnapshot>();

      repoA.snapshotHandler = (_) => lateResponse.future;

      await pumpScope(tester);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      session.switchTo('B');
      await tester.pump();
      await settle(tester);

      expect(find.text('$accountBSales'), findsOneWidget);

      lateResponse.complete(snapshotFor('all', accountASales, 11));
      await settle(tester);

      expect(find.text('$accountASales'), findsNothing);
      expect(find.text('$accountBSales'), findsOneWidget);
    });

    testWidgets('closes the cubit of the previous account', (tester) async {
      await pumpScope(tester);

      final first = created.single;

      session.switchTo('B');
      await tester.pump();
      await settle(tester);

      expect(first.isClosed, true);
      expect(created.length, 2);
    });

    testWidgets('switching to the same account keeps the same cubit', (
      tester,
    ) async {
      await pumpScope(tester);

      session.switchTo('A');
      await settle(tester);

      expect(created.length, 1);
      expect(created.single.isClosed, false);
    });
  });
}
