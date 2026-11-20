import 'package:flutter_test/flutter_test.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/domain/entities/branch_summary.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/domain/entities/monitoring_snapshot.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/domain/entities/monitoring_update.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/domain/entities/recent_operation.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/domain/usecases/monitoring_update_processor.dart';

void main() {
  const processor = MonitoringUpdateProcessor();

  final now = DateTime.utc(2026, 11, 20);

  MonitoringSnapshot createSnapshot({
    int sequence = 10,
    int sales = 100000,
    int cash = 50000,
    List<RecentOperation> operations = const [],
  }) {
    return MonitoringSnapshot(
      scopeId: 'a1',
      sequence: sequence,
      summary: BranchSummary(
        totalSales: sales,
        totalCash: cash,
      ),
      recentOperations: operations,
      updatedAt: now,
    );
  }

  MonitoringUpdate createUpdate({
    String scopeId = 'a1',
    int sequence = 11,
    int salesDelta = 1000,
    int cashDelta = 500,
    RecentOperation? operation,
  }) {
    return MonitoringUpdate(
      scopeId: scopeId,
      sequence: sequence,
      salesDelta: salesDelta,
      cashDelta: cashDelta,
      createdAt: now,
      operation: operation,
    );
  }

  group('MonitoringUpdateProcessor', () {
    test('applies the next update correctly', () {
      final snapshot = createSnapshot();
      final update = createUpdate();

      final result = processor.process(
        current: snapshot,
        update: update,
      );

      expect(result.status, UpdateProcessingStatus.applied);
      expect(result.snapshot.sequence, 11);
      expect(result.snapshot.summary.totalSales, 101000);
      expect(result.snapshot.summary.totalCash, 50500);
    });

    test('ignores duplicate updates without changing snapshot', () {
      final snapshot = createSnapshot();
      final update = createUpdate(sequence: 10);

      final result = processor.process(
        current: snapshot,
        update: update,
      );

      expect(result.status, UpdateProcessingStatus.duplicate);
      expect(result.snapshot, same(snapshot));
      expect(result.snapshot.summary.totalSales, 100000);
    });

    test('detects a sequence gap without applying the update', () {
      final snapshot = createSnapshot();
      final update = createUpdate(sequence: 12);

      final result = processor.process(
        current: snapshot,
        update: update,
      );

      expect(result.status, UpdateProcessingStatus.gapDetected);
      expect(result.snapshot, same(snapshot));
      expect(result.snapshot.summary.totalSales, 100000);
    });

    test('throws when update belongs to another scope', () {
      final snapshot = createSnapshot();
      final update = createUpdate(scopeId: 'a2');

      expect(
        () => processor.process(
          current: snapshot,
          update: update,
        ),
        throwsArgumentError,
      );
    });

    test('adds the new operation to recent operations', () {
      final operation = RecentOperation(
        id: 'op-11',
        description: 'بيع ذهب',
        amount: 1000,
        createdAt: now,
      );

      final result = processor.process(
        current: createSnapshot(),
        update: createUpdate(operation: operation),
      );

      expect(result.snapshot.recentOperations.length, 1);
      expect(result.snapshot.recentOperations.first.id, 'op-11');
    });

    test('keeps only the latest 20 operations', () {
      final operations = List.generate(
        20,
        (index) => RecentOperation(
          id: 'op-$index',
          description: 'Operation $index',
          amount: 100,
          createdAt: now,
        ),
      );

      final newOperation = RecentOperation(
        id: 'op-new',
        description: 'New operation',
        amount: 200,
        createdAt: now,
      );

      final result = processor.process(
        current: createSnapshot(operations: operations),
        update: createUpdate(operation: newOperation),
      );

      expect(result.snapshot.recentOperations.length, 20);
      expect(result.snapshot.recentOperations.first.id, 'op-new');
      expect(result.snapshot.recentOperations.last.id, 'op-18');
    });
  });
}