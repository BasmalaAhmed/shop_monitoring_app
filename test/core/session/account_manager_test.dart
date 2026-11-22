import 'package:flutter_test/flutter_test.dart';
import 'package:shop_monitoring_app/core/session/account_manager.dart';
import 'package:shop_monitoring_app/core/session/account_session.dart';

void main() {
  test('switches the session first, then clears the previous account',
      () async {
    final events = <String>[];

    final session = AccountSession(initialAccountId: 'shop_1');
    session.addListener(() => events.add('session:${session.accountId}'));

    final manager = AccountManager(
      session: session,
      clearAccountData: (accountId) async => events.add('clear:$accountId'),
    );

    await manager.switchTo('shop_2');

    expect(events, ['session:shop_2', 'clear:shop_1']);
  });

  test('does nothing when switching to the same account', () async {
    final events = <String>[];

    final session = AccountSession(initialAccountId: 'shop_1');
    session.addListener(() => events.add('session'));

    final manager = AccountManager(
      session: session,
      clearAccountData: (accountId) async => events.add('clear:$accountId'),
    );

    await manager.switchTo('shop_1');

    expect(events, isEmpty);
  });
}