import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shop_monitoring_app/core/errors/network_exception.dart';
import 'package:shop_monitoring_app/core/theme/app_theme.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/domain/entities/branch.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/domain/entities/branch_summary.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/domain/entities/monitoring_snapshot.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/domain/usecases/monitoring_update_processor.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/presentation/manager/cubits/branch_monitoring_cubit/branch_monitoring_cubit.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/presentation/manager/cubits/branch_monitoring_cubit/branch_monitoring_state.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/presentation/views/branch_monitoring_view.dart';

import '../../../../helpers/fake_monitoring_dependencies.dart';

void main() {
  late FakeMonitoringRepo monitoringRepo;
  late FakeGoldPriceRepo goldPriceRepo;
  late FakeConnectivityService connectivity;
  late BranchMonitoringCubit cubit;

  final now = DateTime.utc(2026, 11, 20);

  const bannerText = 'تعرض آخر البيانات المحفوظة';
  const failureText = 'حدث خطأ أثناء تحميل البيانات';
  const retryText = 'إعادة المحاولة';
  const backText = 'رجوع';
  const noConnectionText = 'لا يوجد اتصال بالإنترنت ولا توجد بيانات محفوظة';
  const branchNoDataText =
      'لا توجد بيانات محفوظة لهذا الفرع. تحقق من الاتصال وحاول مرة أخرى';

  MonitoringSnapshot createSnapshot(
    String scopeId, {
    bool isFromCache = false,
  }) {
    return MonitoringSnapshot(
      scopeId: scopeId,
      sequence: 0,
      summary: BranchSummary(totalSales: 100000, totalCash: 50000),
      recentOperations: const [],
      updatedAt: now,
      isFromCache: isFromCache,
    );
  }

  setUp(() {
    monitoringRepo = FakeMonitoringRepo();
    goldPriceRepo = FakeGoldPriceRepo();
    connectivity = FakeConnectivityService();

    monitoringRepo.branches = const [
      Branch(id: 'a1', name: 'فرع القاهرة'),
      Branch(id: 'a2', name: 'فرع الإسكندرية'),
    ];

    monitoringRepo.snapshots = {
      'all': createSnapshot('all'),
      'a1': createSnapshot('a1'),
      'a2': createSnapshot('a2'),
    };

    cubit = BranchMonitoringCubit(
      monitoringRepo: monitoringRepo,
      goldPriceRepo: goldPriceRepo,
      connectivity: connectivity,
      updateProcessor: const MonitoringUpdateProcessor(),
    );
  });

  tearDown(() async {
    await cubit.close();
    await monitoringRepo.dispose();
    await goldPriceRepo.dispose();
    await connectivity.dispose();
  });

  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }

  Future<void> pumpView(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        locale: const Locale('ar'),
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        supportedLocales: const [Locale('ar')],
        home: BlocProvider.value(
          value: cubit,
          child: const BranchMonitoringView(),
        ),
      ),
    );

    await tester.runAsync(() => cubit.load());
    await settle(tester);
  }

  group('BranchMonitoringView', () {
    testWidgets('shows summary and gold price without the offline banner', (
      tester,
    ) async {
      await pumpView(tester);

      expect(find.text('100000'), findsOneWidget);
      expect(find.text('50000'), findsOneWidget);
      expect(find.text('4000 جنيه'), findsOneWidget);
      expect(find.text(bannerText), findsNothing);
    });

    testWidgets('shows the offline banner when connectivity is lost', (
      tester,
    ) async {
      await pumpView(tester);

      connectivity.setOnline(false);
      await settle(tester);

      expect(find.text(bannerText), findsOneWidget);
      expect(find.textContaining('آخر تحديث'), findsNWidgets(2));
      expect(find.text('100000'), findsOneWidget);
    });

    testWidgets('shows the banner for cached data even when online', (
      tester,
    ) async {
      monitoringRepo.snapshots['all'] = createSnapshot(
        'all',
        isFromCache: true,
      );

      await pumpView(tester);

      expect(find.text(bannerText), findsOneWidget);
    });

    testWidgets('failed first load shows retry without a back button', (
      tester,
    ) async {
      monitoringRepo.snapshotHandler = (_) async =>
          throw const NetworkException();

      await pumpView(tester);

      expect(find.text(noConnectionText), findsOneWidget);
      expect(find.text(retryText), findsOneWidget);
      expect(find.text(backText), findsNothing);
    });

    testWidgets('failed branch switch shows retry and back, back restores', (
      tester,
    ) async {
      await pumpView(tester);

      monitoringRepo.snapshotHandler = (id) async {
        if (id == 'a1') throw const NetworkException();

        return monitoringRepo.snapshots[id]!;
      };

      await tester.runAsync(() => cubit.selectScope('a1'));
      await tester.pump();

      expect(find.text(branchNoDataText), findsOneWidget);
      expect(find.text(retryText), findsOneWidget);
      expect(find.text(backText), findsOneWidget);

      await tester.tap(find.text(backText));
      await tester.pump();

      expect(find.text(branchNoDataText), findsNothing);
      expect(find.text('100000'), findsOneWidget);
    });

    testWidgets('retry reloads the failed branch', (tester) async {
      await pumpView(tester);

      monitoringRepo.snapshotHandler = (id) async {
        if (id == 'a1') throw const NetworkException();

        return monitoringRepo.snapshots[id]!;
      };

      await tester.runAsync(() => cubit.selectScope('a1'));
      await tester.pump();

      monitoringRepo.snapshotHandler = null;

      await tester.tap(find.text(retryText));

      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();

      expect(find.text(branchNoDataText), findsNothing);

      final state = cubit.state as BranchMonitoringSuccess;

      expect(state.selectedScopeId, 'a1');
    });

    testWidgets('non-network error shows the generic message', (tester) async {
      monitoringRepo.snapshotHandler = (_) async => throw StateError('boom');

      await pumpView(tester);

      expect(find.text(failureText), findsOneWidget);
      expect(find.text(noConnectionText), findsNothing);
      expect(find.text(retryText), findsOneWidget);
    });

    testWidgets('shows a progress bar while a branch is loading', (
      tester,
    ) async {
      await pumpView(tester);

      final slow = Completer<MonitoringSnapshot>();

      monitoringRepo.snapshotHandler = (id) {
        if (id == 'a1') return slow.future;

        return Future.value(monitoringRepo.snapshots[id]!);
      };

      late Future<void> pending;

      await tester.runAsync(() async {
        pending = cubit.selectScope('a1');
      });
      await tester.pump();

      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      slow.complete(monitoringRepo.snapshots['a1']!);
      await tester.runAsync(() => pending);
      await tester.pump();

      expect(find.byType(LinearProgressIndicator), findsNothing);
    });
  });
}
