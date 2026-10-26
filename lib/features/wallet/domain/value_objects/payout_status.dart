enum PayoutStatus {
  pending('Pending Review'),
  approved('Approved & Processing'),
  settled('Settled / Transferred'),
  rejected('Rejected');

  final String label;
  const PayoutStatus(this.label);

  static PayoutStatus fromString(String? value) {
    return PayoutStatus.values.firstWhere(
      (e) => e.name.toLowerCase() == (value ?? '').toLowerCase(),
      orElse: () => PayoutStatus.pending,
    );
  }
}
