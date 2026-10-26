import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/domain/failures/app_failure.dart';
import '../../../../core/presentation/utils/fp_framework.dart';
import '../domain/entities/payout_request.dart';
import '../domain/entities/wallet_transaction.dart';
import '../domain/value_objects/payout_status.dart';
import '../domain/value_objects/transaction_type.dart';

class WalletRemoteService {
  final FirebaseFirestore _firestore;

  WalletRemoteService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _userTransactionsRef(
          String userId) =>
      _firestore.collection('users').doc(userId).collection('transactions');

  CollectionReference<Map<String, dynamic>> get _payoutsRef =>
      _firestore.collection('payouts');

  CollectionReference<Map<String, dynamic>> get _deliveriesRef =>
      _firestore.collection('deliveries');

  /// Real-time stream of user transaction ledger
  Stream<List<WalletTransaction>> watchUserTransactions(String userId) {
    return _userTransactionsRef(userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => WalletTransaction.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// Real-time stream of all platform payout requests (for Operations / Admin)
  Stream<List<PayoutRequest>> watchAllPayoutRequests({PayoutStatus? statusFilter}) {
    Query<Map<String, dynamic>> query =
        _payoutsRef.orderBy('createdAt', descending: true);

    if (statusFilter != null) {
      query = query.where('status', isEqualTo: statusFilter.name);
    }

    return query.snapshots().map((snapshot) => snapshot.docs
        .map((doc) => PayoutRequest.fromMap(doc.data(), doc.id))
        .toList());
  }

  /// Real-time stream of a specific driver's payout requests
  Stream<List<PayoutRequest>> watchDriverPayoutRequests(String driverId) {
    return _payoutsRef
        .where('driverId', isEqualTo: driverId)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => PayoutRequest.fromMap(doc.data(), doc.id))
              .toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  /// Top-up user digital wallet balance
  Future<Either<AppFailure, Unit>> topUpWallet({
    required String userId,
    required double amount,
    required String reference,
  }) async {
    if (amount <= 0) {
      return left(
          const ServerFailure(message: 'Top-up amount must be greater than zero.'));
    }

    try {
      final batch = _firestore.batch();
      final userRef = _firestore.collection('users').doc(userId);

      // 1. Increment wallet balance
      batch.update(userRef, {
        'walletBalance': FieldValue.increment(amount),
      });

      // 2. Append transaction ledger document
      final txDoc = _userTransactionsRef(userId).doc();
      final transaction = WalletTransaction(
        id: txDoc.id,
        userId: userId,
        amount: amount,
        type: TransactionType.topUp,
        title: 'Digital Wallet Top-Up',
        description: 'Instant top-up via card/transfer (Ref: $reference)',
        referenceId: reference,
        createdAt: DateTime.now(),
      );
      batch.set(txDoc, transaction.toMap());

      await batch.commit();
      return right(unit);
    } catch (e) {
      return left(ServerFailure(message: 'Wallet top-up failed: $e'));
    }
  }

  /// Submit a formal driver payout request (locks amount from wallet balance)
  Future<Either<AppFailure, Unit>> submitPayoutRequest({
    required String driverId,
    required String driverName,
    required String driverPhone,
    required double currentBalance,
    required double amount,
    required String bankName,
    required String accountNumber,
    required String accountName,
  }) async {
    if (amount <= 0) {
      return left(const ServerFailure(
          message: 'Withdrawal amount must be greater than zero.'));
    }
    if (amount > currentBalance) {
      return left(const ServerFailure(
          message: 'Insufficient balance for requested withdrawal.'));
    }

    try {
      final batch = _firestore.batch();
      final userRef = _firestore.collection('users').doc(driverId);
      final payoutDoc = _payoutsRef.doc();

      // 1. Deduct amount from driver balance immediately
      batch.update(userRef, {
        'walletBalance': FieldValue.increment(-amount),
      });

      // 2. Create payout document
      final payout = PayoutRequest(
        id: payoutDoc.id,
        driverId: driverId,
        driverName: driverName,
        driverPhone: driverPhone,
        amount: amount,
        bankName: bankName.trim(),
        accountNumber: accountNumber.trim(),
        accountName: accountName.trim(),
        status: PayoutStatus.pending,
        createdAt: DateTime.now(),
      );
      batch.set(payoutDoc, payout.toMap());

      // 3. Record pending withdrawal in driver ledger
      final txDoc = _userTransactionsRef(driverId).doc();
      final transaction = WalletTransaction(
        id: txDoc.id,
        userId: driverId,
        amount: amount,
        type: TransactionType.withdrawal,
        title: 'Bank Payout Request',
        description: 'Payout to ${bankName.trim()} (${accountNumber.trim()})',
        referenceId: payoutDoc.id,
        createdAt: DateTime.now(),
      );
      batch.set(txDoc, transaction.toMap());

      await batch.commit();
      return right(unit);
    } catch (e) {
      return left(ServerFailure(message: 'Payout request failed: $e'));
    }
  }

  /// Admin approves and marks payout as settled / paid
  Future<Either<AppFailure, Unit>> approvePayout({
    required String payoutId,
    required String adminId,
    required String transactionRef,
  }) async {
    try {
      await _payoutsRef.doc(payoutId).update({
        'status': PayoutStatus.settled.name,
        'processedAt': DateTime.now().toIso8601String(),
        'processedBy': adminId,
        'transactionRef': transactionRef.trim(),
      });
      return right(unit);
    } catch (e) {
      return left(ServerFailure(message: 'Failed to settle payout: $e'));
    }
  }

  /// Admin rejects payout request and reverses funds back to driver's wallet
  Future<Either<AppFailure, Unit>> rejectPayout({
    required String payoutId,
    required String adminId,
    required String reason,
  }) async {
    try {
      final payoutDoc = await _payoutsRef.doc(payoutId).get();
      if (!payoutDoc.exists || payoutDoc.data() == null) {
        return left(const ServerFailure(message: 'Payout request not found.'));
      }

      final payout = PayoutRequest.fromMap(payoutDoc.data()!, payoutDoc.id);
      if (payout.status != PayoutStatus.pending) {
        return left(const ServerFailure(
            message: 'Only pending payout requests can be rejected.'));
      }

      final batch = _firestore.batch();

      // 1. Mark payout as rejected
      batch.update(_payoutsRef.doc(payoutId), {
        'status': PayoutStatus.rejected.name,
        'processedAt': DateTime.now().toIso8601String(),
        'processedBy': adminId,
        'rejectionReason': reason.trim(),
      });

      // 2. Re-credit the amount back to the driver's wallet
      final userRef = _firestore.collection('users').doc(payout.driverId);
      batch.update(userRef, {
        'walletBalance': FieldValue.increment(payout.amount),
      });

      // 3. Record reversal in driver transaction ledger
      final txDoc = _userTransactionsRef(payout.driverId).doc();
      final reversalTx = WalletTransaction(
        id: txDoc.id,
        userId: payout.driverId,
        amount: payout.amount,
        type: TransactionType.payoutReversal,
        title: 'Payout Reversal / Refund',
        description: 'Rejected: ${reason.trim()} (Ref: $payoutId)',
        referenceId: payoutId,
        createdAt: DateTime.now(),
      );
      batch.set(txDoc, reversalTx.toMap());

      await batch.commit();
      return right(unit);
    } catch (e) {
      return left(ServerFailure(message: 'Failed to reject payout: $e'));
    }
  }

  /// Settle order payment upon successful delivery completion.
  /// Handles Cash on Delivery (COD) commission deduction vs digital wallet earnings payout.
  Future<Either<AppFailure, Unit>> settleOrderPayment({
    required String orderId,
    required String driverId,
    required String customerId,
    required double totalFare,
    required double driverEarnings,
    required double platformCommission,
    required String paymentMethod,
    required String trackingNumber,
  }) async {
    try {
      final batch = _firestore.batch();
      final isCod = paymentMethod == 'cashOnDelivery';

      // 1. Update order document payment status
      final orderRef = _deliveriesRef.doc(orderId);
      batch.update(orderRef, {
        'pricing.isPaid': true,
        'pricing.driverEarnings': driverEarnings,
        'pricing.platformCommission': platformCommission,
        'isSettled': true,
        'settledAt': DateTime.now().toIso8601String(),
      });

      final driverRef = _firestore.collection('users').doc(driverId);
      final driverTxDoc = _userTransactionsRef(driverId).doc();

      if (isCod) {
        // Driver collected 100% physical cash. Deduct 20% platform commission from their digital wallet.
        batch.update(driverRef, {
          'walletBalance': FieldValue.increment(-platformCommission),
        });

        final codTx = WalletTransaction(
          id: driverTxDoc.id,
          userId: driverId,
          amount: platformCommission,
          type: TransactionType.codCommission,
          title: 'COD Platform Commission (20%)',
          description:
              'Deduction for cash collected on Waybill $trackingNumber',
          referenceId: orderId,
          createdAt: DateTime.now(),
        );
        batch.set(driverTxDoc, codTx.toMap());
      } else {
        // Customer paid digitally (Wallet / Card). Credit 80% earnings to driver digital wallet.
        batch.update(driverRef, {
          'walletBalance': FieldValue.increment(driverEarnings),
        });

        final tripPayoutTx = WalletTransaction(
          id: driverTxDoc.id,
          userId: driverId,
          amount: driverEarnings,
          type: TransactionType.tripPayout,
          title: 'Trip Earnings (80%)',
          description:
              'Completed delivery payout for Waybill $trackingNumber',
          referenceId: orderId,
          createdAt: DateTime.now(),
        );
        batch.set(driverTxDoc, tripPayoutTx.toMap());
      }

      await batch.commit();
      return right(unit);
    } catch (e) {
      return left(ServerFailure(message: 'Order settlement failed: $e'));
    }
  }
}
