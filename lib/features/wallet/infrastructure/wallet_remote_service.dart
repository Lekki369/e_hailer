import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/domain/failures/app_failure.dart';
import '../../../../core/presentation/utils/fp_framework.dart';
import '../domain/entities/wallet_transaction.dart';
import '../domain/value_objects/transaction_type.dart';

class WalletRemoteService {
  final FirebaseFirestore _firestore;

  WalletRemoteService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _userTransactionsRef(
          String userId) =>
      _firestore.collection('users').doc(userId).collection('transactions');

  /// Real-time stream of user transaction ledger
  Stream<List<WalletTransaction>> watchUserTransactions(String userId) {
    return _userTransactionsRef(userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => WalletTransaction.fromMap(doc.data(), doc.id))
            .toList());
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

  /// Request withdrawal / bank payout
  Future<Either<AppFailure, Unit>> requestWithdrawal({
    required String userId,
    required double currentBalance,
    required double amount,
    required String bankName,
    required String accountNumber,
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
      final userRef = _firestore.collection('users').doc(userId);

      // 1. Deduct wallet balance
      batch.update(userRef, {
        'walletBalance': FieldValue.increment(-amount),
      });

      // 2. Record ledger transaction
      final txDoc = _userTransactionsRef(userId).doc();
      final transaction = WalletTransaction(
        id: txDoc.id,
        userId: userId,
        amount: amount,
        type: TransactionType.withdrawal,
        title: 'Bank Transfer Withdrawal',
        description: 'Payout to $bankName ($accountNumber)',
        referenceId: 'WD-${DateTime.now().millisecondsSinceEpoch}',
        createdAt: DateTime.now(),
      );
      batch.set(txDoc, transaction.toMap());

      await batch.commit();
      return right(unit);
    } catch (e) {
      return left(ServerFailure(message: 'Withdrawal request failed: $e'));
    }
  }

  /// Record a transaction directly into user ledger
  Future<Either<AppFailure, Unit>> recordTransaction({
    required String userId,
    required WalletTransaction transaction,
  }) async {
    try {
      final docRef = _userTransactionsRef(userId).doc();
      final finalTx = transaction.copyWith(id: docRef.id);
      await docRef.set(finalTx.toMap());
      return right(unit);
    } catch (e) {
      return left(
          ServerFailure(message: 'Failed to record transaction: $e'));
    }
  }
}
