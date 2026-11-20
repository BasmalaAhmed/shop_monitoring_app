import 'package:shop_monitoring_app/features/branch_monitoring/domain/entities/recent_operation.dart';

class RecentOperationModel {
  final String id;
  final String title;
  final int amount;
  final DateTime at;

  const RecentOperationModel({
    required this.id,
    required this.title,
    required this.amount,
    required this.at,
  });

  factory RecentOperationModel.fromJson(Map<String, dynamic> json) {
    return RecentOperationModel(
      id: json['id'] as String,
      title: json['title'] as String,
      amount: (json['amount'] as num).toInt(),
      at: DateTime.parse(json['at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'at': at.toUtc().toIso8601String(),
    };
  }

  RecentOperation toEntity() {
    return RecentOperation(
      id: id,
      description: title,
      amount: amount,
      createdAt: at,
    );
  }
}
