import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/infrastructure/operations_api.dart';
import '../../../../core/infrastructure/stream_result.dart';

import '../../../../core/domain/failures/app_failure.dart';
import '../../../../core/presentation/utils/fp_framework.dart';
import '../domain/entities/delivery_dispute.dart';
import '../domain/value_objects/dispute_status.dart';

class DisputeRemoteService {
  final FirebaseFirestore _firestore;
  final OperationsApi _api;

  DisputeRemoteService({FirebaseFirestore? firestore, OperationsApi? api})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _api = api ?? OperationsApi();

  CollectionReference<Map<String, dynamic>> get _disputesRef =>
      _firestore.collection('disputes');

  /// File a new delivery dispute or driver incident failure report
  Future<Either<AppFailure, DeliveryDispute>> fileDispute(
    DeliveryDispute dispute,
  ) async {
    final result = await _api.execute('fileDispute', {
      'orderId': dispute.orderId,
      'category': dispute.category.name,
      'description': dispute.description,
      'evidenceNotes': dispute.evidenceNotes,
    });
    return result.map(
      (data) => DeliveryDispute.fromMap(data, data['id'] as String),
    );
  }

  Stream<Either<AppFailure, List<DeliveryDispute>>> _watch(
    Query<Map<String, dynamic>> query,
  ) => streamResult(
    query.snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => DeliveryDispute.fromMap(doc.data(), doc.id))
          .toList(),
    ),
  );
  Stream<Either<AppFailure, List<DeliveryDispute>>> watchAllDisputes() =>
      _watch(_disputesRef.orderBy('createdAt', descending: true));
  Stream<Either<AppFailure, List<DeliveryDispute>>> watchDisputesForOrder(
    String orderId,
  ) => _watch(_disputesRef.where('orderId', isEqualTo: orderId));
  Stream<Either<AppFailure, List<DeliveryDispute>>> watchUserDisputes(
    String userId,
  ) => _watch(_disputesRef.where('claimantId', isEqualTo: userId));

  /// Assign a dispute ticket to an operations support officer (osTicket pattern)
  Future<Either<AppFailure, Unit>> assignDisputeToAgent({
    required String disputeId,
    required String agentId,
    required String agentName,
  }) async {
    return (await _api.execute('assignDispute', {
      'disputeId': disputeId,
      'agentId': agentId,
    })).map((_) => unit);
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
    return (await _api.execute('resolveDispute', {
      'disputeId': disputeId,
      'status': status.name,
      'resolutionNotes': resolutionNotes,
      'refundAmount': ?refundAmount,
    })).map((_) => unit);
  }
}
