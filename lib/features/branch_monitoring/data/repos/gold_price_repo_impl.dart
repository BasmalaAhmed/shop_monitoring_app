import 'package:shop_monitoring_app/core/errors/network_exception.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/data/datasources/gold_price_api.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/data/datasources/monitoring_local_data_source.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/domain/entities/gold_price.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/domain/repos/gold_price_repo.dart';

class GoldPriceRepoImpl implements GoldPriceRepo {
  GoldPriceRepoImpl(
    this._api,
    this._localDataSource, {
    this.accountId = 'demo_shop',
  });

  final GoldPriceApi _api;
  final MonitoringLocalDataSource _localDataSource;
  final String accountId;

  @override
  Future<GoldPrice> getGoldPrice() async {
    try {
      final model = await _api.fetchGoldPrice();

      await _localDataSource.cacheGoldPrice(
        accountId: accountId,
        goldPrice: model,
      );

      return model.toEntity();
    } on NetworkException {
      final cached = await _localDataSource.getCachedGoldPrice(
        accountId: accountId,
      );

      if (cached != null) return cached.toEntity();

      rethrow;
    }
  }

  @override
  Stream<GoldPrice> watchGoldPrice() {
    return _api.goldPriceUpdates().asyncMap((model) async {
      await _localDataSource.cacheGoldPrice(
        accountId: accountId,
        goldPrice: model,
      );

      return model.toEntity();
    });
  }
}
