import 'package:shop_monitoring_app/features/branch_monitoring/domain/entities/gold_price.dart';

abstract class GoldPriceRepo {
  Future<GoldPrice> getGoldPrice();

  Stream<GoldPrice> watchGoldPrice();
}
