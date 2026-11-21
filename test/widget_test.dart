import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shop_monitoring_app/core/service_locator.dart';
import 'package:shop_monitoring_app/main.dart';

void main() {
  testWidgets('displays branch monitoring screen', (
    WidgetTester tester,
  ) async {
    await setupDependencies();
    startSimulation();

    await tester.pumpWidget(const ShopMonitoringApp());

    await tester.pump(const Duration(seconds: 1));

    expect(find.text('مراقبة الفروع'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await disposeDependencies();
  });
}
