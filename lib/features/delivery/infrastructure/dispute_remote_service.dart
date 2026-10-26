import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/domain/failures/app_failure.dart';
import '../../../../core/presentation/utils/fp_framework.dart';
import '../../wallet/domain/value_objects/transaction_type.dart';
import '../domain/entities/delivery_dispute.dart';
import '../domain/value_objects/delivery_status.dart';
import '../domain/value_objects/dispute_category.dart';
import '../domain/value_objects/dispute_status.dart';

class DisputeRemoteService {
  final FirebaseFirestore _firestore;

  DisputeRemoteService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _disputesRef =>
      _firestore.collection('disputes');

  CollectionReference<Map<String, dynamic>> get _deliveriesRef =>
      _firestore.collection('deliveries');

  CollectionReference<Map<String, dynamic>> get _usersRef =>
      _firestore.collection('users');

  /// File a new delivery dispute or driver incident failure report
  Future<Either<AppFailure, DeliveryDispute>> fileDispute(
      DeliveryDispute dispute) async {
    try {
      final docRef = _disputesRef.doc();
      final finalDispute = dispute.copyWith(id: docRef.id);

      final batch = _firestore.batch();
      batch.set(docRef, finalDispute.toMap());

      // If filed by a driver or represents delivery failure, update order status
      final isDriverFailure = dispute.claimantRole == 'driver' ||
          dispute.category == DisputeCategory.unreachableRecipient ||
          dispute.category == DisputeCategory.wrongAddress ||
          dispute.category == DisputeCategory.packageRefused;

      if (isDriverFailure && dispute.orderId.isNotEmpty) {
        final orderDocRef = _deliveriesRef.doc(dispute.orderId);
        batch.update(orderDocRef, {
          'status': DeliveryStatus.failedDelivery.name,
          'cancellationReason':
              'Delivery failed: ${dispute.category.label} - ${dispute.description}',
          'cancelledByRole': 'driver',
          'cancelledAt': DateTime.now().toIso8601String(),
        });
      }

      await batch.commit();
      return right(finalDispute);
    } catch (e) {
      return left(ServerFailure(message: 'Failed to file dispute ticket: $e'));
    }
  }

  /// Watch real-time stream of all disputes across the platform (for Operations Dispatch)
  Stream<List<DeliveryDispute>> watchAllDisputes() {
    return _disputesRef
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => DeliveryDispute.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// Watch real-time stream of disputes for a specific order
  Stream<List<DeliveryDispute>> watchDisputesForOrder(String orderId) {
    return _disputesRef
        .where('orderId', isEqualTo: orderId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => DeliveryDispute.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// Watch user's filed disputes
  Stream<List<DeliveryDispute>> watchUserDisputes(String userId) {
    return _disputesRef
        .where('claimantId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => DeliveryDispute.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// Resolve a dispute ticket with optional customer wallet refund or hub return
  Future<Either<AppFailure, Unit>> resolveDispute({
    required String disputeId,
    required String orderId,
    required DisputeStatus status,
    required String resolvedBy,
    required String resolutionNotes,
    double? refundAmount,
    String? customerId,
    String? returnTrackingNumber,
  }) async {
    try {
      final now = DateTime.now();

      await _firestore.runTransaction((transaction) async {
        final disputeDocRef = _disputesRef.doc(disputeId);

        final updateData = <String, dynamic>{
          'status': status.name,
          'resolvedAt': now.toIso8601String(),
          'resolvedBy': resolvedBy,
          'resolutionNotes': resolutionNotes,
        };

        if (refundAmount != null && refundAmount > 0) {
          updateData['refundAmount'] = refundAmount;
        }
        if (returnTrackingNumber != null) {
          updateData['returnTrackingNumber'] = returnTrackingNumber;
        }

        transaction.update(disputeDocRef, updateData);

        // Case 1: Customer Refund Authorized
        if (status == DisputeStatus.resolvedRefund &&
            refundAmount != null &&
            refundAmount > 0 &&
            customerId != null &&
            customerId.isNotEmpty) {
          // 1. Credit customer wallet
          final customerDocRef = _usersRef.doc(customerId);
          transaction.update(customerDocRef, {
            'walletBalance': FieldValue.increment(refundAmount),
          });

          // 2. Add refund ledger record
          final txDocRef =
              _firestore.collection('wallets').doc(customerId).collection('transactions').doc();

          transaction.set(txDocRef, {
            'userId': customerId,
            'amount': refundAmount,
            'type': TransactionType.refund.name,
            'title': 'Dispute Refund: Order #$orderId',
            'createdAt': now.toIso8601String(),
            'reference': 'DISPUTE-$disputeId',
            'status': 'settled',
          });
        }

        // Case 2: Return to Hub Authorized
        if (status == DisputeStatus.resolvedReturn && orderId.isNotEmpty) {
          final orderDocRef = _deliveriesRef.doc(orderId);
          transaction.update(orderDocRef, {
            'status': DeliveryStatus.returnedToHub.name,
            'resolutionNotes': resolutionNotes,
            'returnTrackingNumber': returnTrackingNumber,
          });
        }
      });

      return right(unit);
    } catch (e) {
      return left(ServerFailure(message: 'Failed to arbitrate dispute: $e'));
    }
  }
}
