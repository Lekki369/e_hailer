part of 'operations_service.dart';

Future<Json> _submitPayout(_CommandContext c) async {
  c.allowRoles({'driver'});
  final amount = minorUnits(c.input['amount']);
  final balance = minorUnits(
    c.actor['walletBalance'] ?? 0,
    allowNegative: true,
  );
  requireCondition(
    amount > 0 && balance >= amount,
    'Your available balance is too low for this withdrawal.',
    'insufficient-balance',
  );
  final account = requiredText(c.input['accountNumber'], 'Account number', 30);
  requireCondition(
    RegExp(r'^\d{5,30}$').hasMatch(account),
    'Enter a valid bank account number.',
  );
  final payout = <String, dynamic>{
    'id': c.eventId,
    'driverId': c.uid,
    'driverName': c.actor['fullName'],
    'driverPhone': c.actor['phone'],
    'amount': amount / 100,
    'bankName': requiredText(c.input['bankName'], 'Bank name', 100),
    'accountName': requiredText(c.input['accountName'], 'Account name', 100),
    'accountNumber': account,
    'status': 'pending',
    'createdAt': c.timestamp,
  };
  c.tx.create('payouts/${c.eventId}', payout);
  c.tx.update('users/${c.uid}', {'walletBalance': (balance - amount) / 100});
  c.ledger(
    c.uid,
    'payout-${c.eventId}',
    amount / 100,
    'withdrawal',
    'Bank payout requested',
    c.eventId,
  );
  return {'id': c.eventId};
}

Future<Json> _processPayout(_CommandContext c, String command) async {
  c.allowRoles({'admin'});
  final id = identifier(c.input['payoutId']);
  final payout = existing(await c.tx.get('payouts/$id'));
  final driverId = payout['driverId'] as String;
  final driver = existing(await c.tx.get('users/$driverId'));
  final target = command == 'approvePayout' ? 'settled' : 'rejected';
  if (payout['status'] == target) return {'alreadyProcessed': true};
  requireCondition(
    payout['status'] == 'pending',
    'This payout has already been processed.',
    'conflict',
  );
  final update = <String, dynamic>{
    'status': target,
    'processedAt': c.timestamp,
    'processedBy': c.uid,
  };
  if (target == 'settled') {
    // Records a manual bank transfer confirmed by an administrator; it does not initiate a transfer.
    update['transactionRef'] = requiredText(
      c.input['transactionRef'],
      'Bank transfer reference',
      128,
    );
  } else {
    update['rejectionReason'] = requiredText(
      c.input['reason'],
      'Rejection reason',
      500,
    );
    final balance = minorUnits(
      driver['walletBalance'] ?? 0,
      allowNegative: true,
    );
    final amount = minorUnits(payout['amount']);
    c.tx.update('users/$driverId', {'walletBalance': (balance + amount) / 100});
    c.ledger(
      driverId,
      'reversal-$id',
      amount / 100,
      'payoutReversal',
      'Payout request reversed',
      id,
    );
  }
  c.tx.update('payouts/$id', update);
  c.tx.create('payouts/$id/audit/${c.eventId}', {'actorId': c.uid, ...update});
  return {};
}
