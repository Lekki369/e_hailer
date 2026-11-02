import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../../../core/domain/command_store.dart';
import '../../../core/domain/operation_failure.dart';
import 'payment_gateway.dart';

/// The intent is durable before contacting Paystack. Only verified settlement
/// may create a ledger entry; client retries and webhooks share this transaction.
class PaymentService {
  final CommandStore store;
  final PaymentGateway gateway;
  final DateTime Function() clock;
  PaymentService({
    required this.store,
    required this.gateway,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;

  static const commands = {
    'initializeWalletTopUp',
    'getWalletTopUp',
    'verifyWalletTopUp',
  };
  static bool validReference(String reference) =>
      RegExp(r'^EH-TOPUP-[a-f0-9]{40}$').hasMatch(reference);

  Future<Json> execute(
    String command,
    String uid,
    Json input,
    String requestId,
  ) async {
    identifier(uid);
    requireCondition(
      RegExp(r'^[A-Za-z0-9_-]{16,128}$').hasMatch(requestId),
      'Invalid request key.',
    );
    switch (command) {
      case 'initializeWalletTopUp':
        return {
          'topUp': await initialize(uid, input['amountMinor'], requestId),
        };
      case 'getWalletTopUp':
        final intent = await store.transaction((tx) async {
          final user = existing(await tx.get('users/$uid'));
          final reference = user['pendingTopUpReference'];
          return reference is String
              ? tx.get('paymentIntents/$reference')
              : null;
        });
        requireCondition(
          intent == null || intent['uid'] == uid,
          'This payment belongs to another account.',
          'permission-denied',
        );
        return {'topUp': intent == null ? null : _view(intent)};
      case 'verifyWalletTopUp':
        final reference = requiredText(
          input['reference'],
          'Payment reference',
          80,
        );
        requireCondition(
          validReference(reference),
          'Invalid payment reference.',
        );
        return {'topUp': await verify(reference, uid: uid)};
      default:
        throw const OperationFailure('not-found', 'Unknown payment operation.');
    }
  }

  Future<Json> initialize(String uid, dynamic amount, String key) async {
    requireCondition(
      amount is int && amount >= 10000 && amount <= 100000000,
      'Top up between ₦100 and ₦1,000,000, with at most two decimal places.',
    );
    final reference =
        'EH-TOPUP-${sha256.convert(utf8.encode('$uid:$key')).toString().substring(0, 40)}';
    final now = clock().toUtc();
    final prepared = await store.transaction((tx) async {
      final user = existing(await tx.get('users/$uid'));
      requireCondition(
        {'customer', 'driver'}.contains(user['role']),
        'This account cannot top up a wallet.',
        'permission-denied',
      );
      final old = await tx.get('paymentIntents/$reference');
      final pendingRef = user['pendingTopUpReference'];
      final pending = pendingRef is String && pendingRef != reference
          ? await tx.get('paymentIntents/$pendingRef')
          : null;
      if (old != null) {
        requireCondition(
          old['amountMinor'] == amount,
          'This request key was used for a different amount.',
          'conflict',
        );
      }
      final active =
          old ??
          (pending != null &&
                  !{
                    'credited',
                    'failed',
                    'abandoned',
                    'initializationFailed',
                  }.contains(pending['status'])
              ? pending
              : null);
      if (active != null) {
        requireCondition(
          active['uid'] == uid,
          'This payment belongs to another account.',
          'permission-denied',
        );
        requireCondition(
          active['mode'] == gateway.mode && active['amountMinor'] == amount,
          'Check your pending top-up before starting a different amount.',
          'conflict',
        );
        if (active['status'] == 'credited' ||
            active['authorizationUrl'] != null ||
            (active['leaseUntilMillis'] as int? ?? 0) >
                now.millisecondsSinceEpoch) {
          return {'intent': active, 'claim': false};
        }
        tx.update('paymentIntents/${active['reference']}', {
          'leaseUntilMillis': now
              .add(const Duration(seconds: 30))
              .millisecondsSinceEpoch,
        });
        return {'intent': active, 'claim': true};
      }
      final email = requiredText(
        user['email'],
        'An account email address',
        120,
      ).toLowerCase();
      requireCondition(
        RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email),
        'An account email address is required to use checkout.',
      );
      final intent = <String, dynamic>{
        'reference': reference,
        'uid': uid,
        'email': email,
        'amountMinor': amount,
        'currency': 'NGN',
        'mode': gateway.mode,
        'status': 'initializing',
        'createdAt': now.toIso8601String(),
        'leaseUntilMillis': now
            .add(const Duration(seconds: 30))
            .millisecondsSinceEpoch,
      };
      tx.create('paymentIntents/$reference', intent);
      tx.update('users/$uid', {'pendingTopUpReference': reference});
      return {'intent': intent, 'claim': true};
    });
    final intent = Json.from(prepared['intent'] as Map);
    if (prepared['claim'] != true) return _view(intent);
    final actualReference = intent['reference'] as String;
    final HostedCheckout checkout;
    try {
      checkout = await gateway.initialize(
        reference: actualReference,
        email: intent['email'] as String,
        amountMinor: intent['amountMinor'] as int,
      );
    } catch (_) {
      final settled = await store.transaction((tx) async {
        final current = existing(
          await tx.get('paymentIntents/$actualReference'),
        );
        if (current['status'] == 'credited') return _view(current);
        if (current['status'] == 'initializing') {
          tx.update('paymentIntents/$actualReference', {
            'status': 'initializationFailed',
            'leaseUntilMillis': 0,
          });
        }
        return null;
      });
      if (settled != null) return settled;
      throw const OperationFailure(
        'payment-initialization-failed',
        'Checkout could not be opened. Check your wallet before retrying.',
      );
    }
    return store.transaction((tx) async {
      final current = existing(await tx.get('paymentIntents/$actualReference'));
      // A webhook may settle before initialization returns; never overwrite it.
      if (current['status'] == 'credited') return _view(current);
      final update = {
        'authorizationUrl': checkout.authorizationUrl,
        'status': 'pending',
        'leaseUntilMillis': 0,
      };
      tx.update('paymentIntents/$actualReference', update);
      return _view({...current, ...update});
    });
  }

  Future<Json?> verify(String reference, {String? uid}) async {
    requireCondition(validReference(reference), 'Invalid payment reference.');
    final intent = await store.transaction(
      (tx) => tx.get('paymentIntents/$reference'),
    );
    if (intent == null && uid == null) return null; // Unrelated merchant event.
    final expected = existing(intent);
    requireCondition(
      uid == null || expected['uid'] == uid,
      'This payment belongs to another account.',
      'permission-denied',
    );
    if (expected['status'] == 'credited') return _view(expected);
    final payment = await gateway.verify(reference);
    requireCondition(
      payment.reference == reference &&
          payment.mode == expected['mode'] &&
          payment.mode == gateway.mode &&
          payment.currency == expected['currency'] &&
          payment.amountMinor == expected['amountMinor'] &&
          payment.email.trim().toLowerCase() == expected['email'],
      'Payment details do not match this top-up. Contact support with the reference.',
      'payment-mismatch',
    );
    return store.transaction((tx) async {
      final current = existing(await tx.get('paymentIntents/$reference'));
      if (current['status'] == 'credited') return _view(current);
      if (payment.status != 'success') {
        final status = {'failed', 'abandoned'}.contains(payment.status)
            ? payment.status
            : 'pending';
        tx.update('paymentIntents/$reference', {'status': status});
        return _view({...current, 'status': status});
      }
      requireCondition(
        RegExp(r'^\d+$').hasMatch(payment.transactionId),
        'Invalid provider transaction.',
        'payment-mismatch',
      );
      final owner = current['uid'] as String;
      final user = existing(await tx.get('users/$owner'));
      final settlementPath =
          'paymentSettlements/paystack-${payment.mode}-${payment.transactionId}';
      final settlement = await tx.get(settlementPath);
      final ledgerPath = 'users/$owner/transactions/topup-$reference';
      final ledger = await tx.get(ledgerPath);
      requireCondition(
        settlement == null && ledger == null,
        'This provider payment has already been accounted for. Contact support.',
        'payment-conflict',
      );
      final now = clock().toUtc().toIso8601String();
      final amount = current['amountMinor'] as int;
      final balance = minorUnits(
        user['walletBalance'] ?? 0,
        allowNegative: true,
      );
      tx.create(settlementPath, {
        'reference': reference,
        'uid': owner,
        'amountMinor': amount,
        'createdAt': now,
      });
      tx.create(ledgerPath, {
        'userId': owner,
        'amount': amount / 100,
        'type': 'topUp',
        'title': payment.mode == 'test'
            ? 'Test wallet top-up'
            : 'Paystack wallet top-up',
        'referenceId': reference,
        'createdAt': now,
      });
      tx.update('users/$owner', {
        'walletBalance': (balance + amount) / 100,
        if (user['pendingTopUpReference'] == reference)
          'pendingTopUpReference': null,
      });
      final update = {
        'status': 'credited',
        'creditedAt': now,
        'providerTransactionId': payment.transactionId,
      };
      tx.update('paymentIntents/$reference', update);
      return _view({...current, ...update});
    });
  }

  static Json _view(Json intent) => {
    for (final key in [
      'reference',
      'amountMinor',
      'currency',
      'mode',
      'status',
      'authorizationUrl',
    ])
      key: intent[key],
  };
}
