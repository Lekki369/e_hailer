/// Resolution and lifecycle status of a delivery dispute ticket
enum DisputeStatus {
  open('Open for Review'),
  underInvestigation('Under Investigation'),
  resolvedRefund('Resolved with Customer Refund'),
  resolvedReturn('Resolved - Return to Hub'),
  rejected('Claim Dismissed / Rejected');

  final String label;
  const DisputeStatus(this.label);

  bool get isPending =>
      this == DisputeStatus.open || this == DisputeStatus.underInvestigation;

  bool get isResolved => !isPending;

  static DisputeStatus fromString(String? value) {
    if (value == null) return DisputeStatus.open;
    final normalized = value.toLowerCase().replaceAll('_', '');
    if (normalized == 'inreview' || normalized == 'underinvestigation') {
      return DisputeStatus.underInvestigation;
    }
    if (normalized == 'resolved') {
      return DisputeStatus.resolvedRefund;
    }
    return DisputeStatus.values.firstWhere(
      (e) => e.name.toLowerCase() == normalized,
      orElse: () => DisputeStatus.open,
    );
  }
}
