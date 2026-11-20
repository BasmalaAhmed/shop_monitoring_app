import 'package:shop_monitoring_app/core/errors/network_exception.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/data/datasources/gold_price_api.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/domain/entities/gold_price.dart';
import 'package:shop_monitoring_app/features/branch_monitoring/domain/repos/gold_price_repo.dart';

class GoldPriceRepositoryImpl implements GoldPriceRepository {
  GoldPriceRepositoryImpl(this._api);

  final GoldPriceApi _api;

  GoldPrice? _cachedGoldPrice;

  @override
  Future<GoldPrice> getGoldPrice() async {
    try {
      final model = await _api.fetchGoldPrice();
      final goldPrice = model.toEntity();

      _cachedGoldPrice = goldPrice;

      return goldPrice;
    } on NetworkException {
      if (_cachedGoldPrice != null) return _cachedGoldPrice!;
      rethrow;
    }
  }

  @override
  Stream<GoldPrice> watchGoldPrice() {
    return _api.goldPriceUpdates().map((model) {
      final goldPrice = model.toEntity();

      _cachedGoldPrice = goldPrice;

      return goldPrice;
    });
  }
}
