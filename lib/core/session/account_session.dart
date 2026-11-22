import 'package:flutter/foundation.dart';

class AccountSession extends ValueNotifier<String> {
  AccountSession({String initialAccountId = defaultAccountId})
    : super(initialAccountId);

  static const defaultAccountId = 'demo_shop';

  String get accountId => value;

  void switchTo(String accountId) {
    value = accountId;
  }
}
