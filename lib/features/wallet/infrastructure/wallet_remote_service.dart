import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/domain/failures/app_failure.dart';
import '../../../../core/infrastructure/operations_api.dart';
import '../../../../core/infrastructure/stream_result.dart';
import '../../../../core/presentation/utils/fp_framework.dart';
import '../domain/entities/payout_request.dart';
import '../domain/entities/wallet_transaction.dart';
import '../domain/value_objects/payout_status.dart';

class WalletRemoteService {
  final FirebaseFirestore _firestore;
  final OperationsApi _api;
  WalletRemoteService({FirebaseFirestore? firestore, OperationsApi? api})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _api = api ?? OperationsApi();
  Future<Either<AppFailure, Unit>> _send(
    String command,
    Map<String, dynamic> data,
  ) async => (await _api.execute(command, data)).map((_) => unit);
  Stream<Either<AppFailure, List<WalletTransaction>>> watchUserTransactions(
    String userId,
  ) => streamResult(
    _firestore
        .collection('users')
        .doc(userId)
        .collection('transactions')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => WalletTransaction.fromMap(doc.data(), doc.id))
              .toList(),
        ),
  );
  Stream<Either<AppFailure, List<PayoutRequest>>> _payouts(
    Query<Map<String, dynamic>> query,
  ) => streamResult(
    query.snapshots().map((snapshot) {
      final payouts = snapshot.docs
          .map((doc) => PayoutRequest.fromMap(doc.data(), doc.id))
          .toList();
      payouts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return payouts;
    }),
  );
  Stream<Either<AppFailure, List<PayoutRequest>>> watchAllPayoutRequests({
    PayoutStatus? statusFilter,
  }) {
    final collection = _firestore.collection('payouts');
    return _payouts(
      statusFilter == null
          ? collection
          : collection.where('status', isEqualTo: statusFilter.name),
    );
  }

  Stream<Either<AppFailure, List<PayoutRequest>>> watchDriverPayoutRequests(
    String driverId,
  ) => _payouts(
    _firestore.collection('payouts').where('driverId', isEqualTo: driverId),
  );
  Future<Either<AppFailure, Unit>> topUpWallet({
    required String userId,
    required double amount,
    required String reference,
  }) async => left(
    const ServerFailure(
      message:
          'Wallet top-ups are not available yet. No payment has been taken.',
    ),
  );
  Future<Either<AppFailure, Unit>> submitPayoutRequest({
    required String driverId,
    required String driverName,
    required String driverPhone,
    required double currentBalance,
    required double amount,
    required String bankName,
    required String accountNumber,
    required String accountName,
  }) => _send('submitPayout', {
    'amount': amount,
    'bankName': bankName.trim(),
    'accountNumber': accountNumber.trim(),
    'accountName': accountName.trim(),
  });
  Future<Either<AppFailure, Unit>> approvePayout({
    required String payoutId,
    required String adminId,
    required String transactionRef,
  }) => _send('approvePayout', {
    'payoutId': payoutId,
    'transactionRef': transactionRef.trim(),
  });
  Future<Either<AppFailure, Unit>> rejectPayout({
    required String payoutId,
    required String adminId,
    required String reason,
  }) => _send('rejectPayout', {'payoutId': payoutId, 'reason': reason.trim()});
}
