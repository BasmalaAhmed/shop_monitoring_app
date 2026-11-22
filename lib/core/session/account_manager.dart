import 'package:shop_monitoring_app/core/session/account_session.dart';

class AccountManager {
  AccountManager({
    required this.session,
    required this.clearAccountData,
  });

  final AccountSession session;

  final Future<void> Function(String accountId) clearAccountData;

  Future<void> switchTo(String accountId) async {
    final previous = session.accountId;

    if (previous == accountId) return;

    session.switchTo(accountId);

    await clearAccountData(previous);
  }
}