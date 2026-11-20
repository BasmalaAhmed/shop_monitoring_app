class RecentOperation {
  final String id;
  final String description;
  final int amount;
  final DateTime createdAt;

  const RecentOperation({
    required this.id,
    required this.description,
    required this.amount,
    required this.createdAt,
  });
}
