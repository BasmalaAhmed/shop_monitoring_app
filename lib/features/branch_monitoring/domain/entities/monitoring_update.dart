class MonitoringUpdate {
  final String scopeId;
  final int sequence;
  final int salesDeltaPiasters;
  final int cashDeltaPiasters;
  final DateTime createdAt;

  const MonitoringUpdate({
    required this.scopeId,
    required this.sequence,
    required this.salesDeltaPiasters,
    required this.cashDeltaPiasters,
    required this.createdAt,
  });
}
