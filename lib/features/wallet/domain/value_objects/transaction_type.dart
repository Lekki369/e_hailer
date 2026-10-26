enum TransactionType {
  tripPayout('Trip Payout', isCredit: true),
  tripPayment('Delivery Payment', isCredit: false),
  topUp('Wallet Top-Up', isCredit: true),
  withdrawal('Bank Withdrawal', isCredit: false);

  final String label;
  final bool isCredit;

  const TransactionType(this.label, {required this.isCredit});
}
