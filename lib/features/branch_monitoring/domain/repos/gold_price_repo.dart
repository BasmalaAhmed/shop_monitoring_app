import 'package:shop_monitoring_app/features/branch_monitoring/domain/entities/gold_price.dart';

abstract class GoldPriceRepository {
  Future<GoldPrice> getGoldPrice();

  Stream<GoldPrice> watchGoldPrice();
}
