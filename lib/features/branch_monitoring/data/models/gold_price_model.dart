import 'package:shop_monitoring_app/features/branch_monitoring/domain/entities/gold_price.dart';

class GoldPriceModel {
  const GoldPriceModel({
    required this.value,
    required this.sequence,
    required this.updatedAt,
  });

  final int value;
  final int sequence;
  final DateTime updatedAt;

  factory GoldPriceModel.fromJson(Map<String, dynamic> json) {
    return GoldPriceModel(
      value: (json['value'] as num).toInt(),
      sequence: (json['sequence'] as num).toInt(),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'value': value,
      'sequence': sequence,
      'updatedAt': updatedAt.toUtc().toIso8601String(),
    };
  }

  GoldPrice toEntity() {
    return GoldPrice(value: value, sequence: sequence, updatedAt: updatedAt);
  }
}
