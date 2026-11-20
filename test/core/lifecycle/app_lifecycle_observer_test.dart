import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shop_monitoring_app/core/lifecycle/app_lifecycle_observer.dart';

void main() {
  group('AppLifecycleObserver', () {
    testWidgets('calls onResumed when app resumes', (tester) async {
      var resumeCount = 0;

      await tester.pumpWidget(
        AppLifecycleObserver(
          onResumed: () => resumeCount++,
          child: const MaterialApp(
            home: Scaffold(
              body: Text('Home'),
            ),
          ),
        ),
      );

      tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.paused,
      );

      expect(resumeCount, 0);

      tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      );

      expect(resumeCount, 1);
      expect(find.text('Home'), findsOneWidget);
    });
  });
}