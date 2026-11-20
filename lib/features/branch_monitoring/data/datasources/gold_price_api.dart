import 'package:shop_monitoring_app/features/branch_monitoring/data/models/gold_price_model.dart';

abstract class GoldPriceApi {
  Future<GoldPriceModel> fetchGoldPrice();

  Stream<GoldPriceModel> goldPriceUpdates();
}
