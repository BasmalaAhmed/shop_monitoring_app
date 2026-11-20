class BranchSummary {
  final int totalSales;
  final int totalCash;

  const BranchSummary({required this.totalSales, required this.totalCash});

  BranchSummary copyWith({int? totalSales, int? totalCash}) {
    return BranchSummary(
      totalSales: totalSales ?? this.totalSales,
      totalCash: totalCash ?? this.totalCash,
    );
  }
}
