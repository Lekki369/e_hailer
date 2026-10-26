enum TransactionType {
  tripPayout('Trip Earnings', isCredit: true),
  tripPayment('Delivery Payment', isCredit: false),
  topUp('Wallet Top-Up', isCredit: true),
  withdrawal('Bank Withdrawal', isCredit: false),
  codCommission('COD Platform Commission', isCredit: false),
  refund('Order Refund', isCredit: true),
  payoutReversal('Payout Reversal', isCredit: true);

  final String label;
  final bool isCredit;

  const TransactionType(this.label, {required this.isCredit});

  static TransactionType fromString(String? value) {
    return TransactionType.values.firstWhere(
      (e) => e.name.toLowerCase() == (value ?? '').toLowerCase(),
      orElse: () => TransactionType.tripPayout,
    );
  }
}
