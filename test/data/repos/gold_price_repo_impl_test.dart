import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shop_monitoring_app/core/errors/network_exception.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/data/datasources/gold_price_api.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/data/models/gold_price_model.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/data/repos/gold_price_repo_impl.dart';

import '../../helpers/fake_local_data_source.dart';

class FakeGoldPriceApi implements GoldPriceApi {
  Future<GoldPriceModel> Function() fetchHandler =
      () async => throw UnimplementedError();

  final StreamController<GoldPriceModel> controller =
      StreamController<GoldPriceModel>.broadcast();

  @override
  Future<GoldPriceModel> fetchGoldPrice() => fetchHandler();

  @override
  Stream<GoldPriceModel> goldPriceUpdates() => controller.stream;
}

void main() {
  late FakeGoldPriceApi api;
  late FakeLocalDataSource local;
  late GoldPriceRepoImpl repo;

  final serverTime = DateTime.utc(2026, 11, 21, 10, 0);
  final cachedTime = DateTime.utc(2026, 11, 21, 9, 0);

  setUp(() {
    api = FakeGoldPriceApi();
    local = FakeLocalDataSource();
    repo = GoldPriceRepoImpl(api, local, accountId: 'shop_1');
  });

  tearDown(() async {
    await api.controller.close();
  });

  group('getGoldPrice', () {
    test('returns the server price and caches it', () async {
      api.fetchHandler = () async =>
          GoldPriceModel(value: 4200, sequence: 7, updatedAt: serverTime);

      final result = await repo.getGoldPrice();

      expect(result.value, 4200);
      expect(result.sequence, 7);
      expect(result.updatedAt, serverTime);

      final cached = await local.getCachedGoldPrice(accountId: 'shop_1');

      expect(cached!.value, 4200);
    });

    test('falls back to the cached price on NetworkException', () async {
      await local.cacheGoldPrice(
        accountId: 'shop_1',
        goldPrice: GoldPriceModel(
          value: 4000,
          sequence: 3,
          updatedAt: cachedTime,
        ),
      );

      api.fetchHandler = () async => throw const NetworkException();

      final result = await repo.getGoldPrice();

      expect(result.value, 4000);
      expect(result.sequence, 3);
      expect(result.updatedAt, cachedTime);
    });

    test('rethrows NetworkException when there is no cached price', () async {
      api.fetchHandler = () async => throw const NetworkException();

      expect(
        () => repo.getGoldPrice(),
        throwsA(isA<NetworkException>()),
      );
    });

    test('does not use the cache for other errors', () async {
      await local.cacheGoldPrice(
        accountId: 'shop_1',
        goldPrice: GoldPriceModel(
          value: 4000,
          sequence: 3,
          updatedAt: cachedTime,
        ),
      );

      api.fetchHandler = () async => throw StateError('server error');

      expect(
        () => repo.getGoldPrice(),
        throwsA(isA<StateError>()),
      );
    });

    test('does not read the cached price of another account', () async {
      await local.cacheGoldPrice(
        accountId: 'shop_2',
        goldPrice: GoldPriceModel(
          value: 4000,
          sequence: 3,
          updatedAt: cachedTime,
        ),
      );

      api.fetchHandler = () async => throw const NetworkException();

      expect(
        () => repo.getGoldPrice(),
        throwsA(isA<NetworkException>()),
      );
    });
  });

  group('watchGoldPrice', () {
    test('emits the price and caches it', () async {
      final future = repo.watchGoldPrice().first;

      api.controller.add(
        GoldPriceModel(value: 4100, sequence: 2, updatedAt: serverTime),
      );

      final price = await future;

      expect(price.value, 4100);
      expect(price.sequence, 2);

      final cached = await local.getCachedGoldPrice(accountId: 'shop_1');

      expect(cached!.value, 4100);
      expect(cached.sequence, 2);
    });
  });
}