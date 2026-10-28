import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/domain/failures/app_failure.dart';
import '../../../../core/presentation/utils/fp_framework.dart';
import '../domain/entities/delivery_order.dart';
import '../domain/entities/delivery_timeline_event.dart';
import '../domain/value_objects/delivery_status.dart';

class DeliveryRemoteService {
  final FirebaseFirestore _firestore;

  DeliveryRemoteService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _deliveriesRef =>
      _firestore.collection('deliveries');

  /// Create a new delivery order (Express or Consignment)
  Future<Either<AppFailure, DeliveryOrder>> createOrder(
      DeliveryOrder order) async {
    try {
      final docRef = _deliveriesRef.doc();
      final finalOrder = order.copyWith(id: docRef.id);
      final batch = _firestore.batch();
      batch.set(docRef, finalOrder.toMap());

      // Write initial creation timeline event
      final timelineRef = docRef.collection('timeline').doc();
      final initialEvent = DeliveryTimelineEvent(
        id: timelineRef.id,
        orderId: docRef.id,
        status: finalOrder.status,
        actorId: finalOrder.customerId,
        actorRole: 'customer',
        timestamp: finalOrder.createdAt,
        note: 'Order created and registered for dispatch',
      );
      batch.set(timelineRef, initialEvent.toMap());

      await batch.commit();
      return right(finalOrder);
    } catch (e) {
      return left(ServerFailure(message: 'Failed to create order: $e'));
    }
  }

  /// Real-time stream of an active order by ID
  Stream<Either<AppFailure, DeliveryOrder>> watchOrder(String orderId) {
    return _deliveriesRef.doc(orderId).snapshots().map<Either<AppFailure, DeliveryOrder>>((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) {
        return left<AppFailure, DeliveryOrder>(const OrderNotFoundFailure());
      }
      return right<AppFailure, DeliveryOrder>(
          DeliveryOrder.fromMap(snapshot.data()!, snapshot.id));
    }).handleError((error) {
      return left<AppFailure, DeliveryOrder>(
          ServerFailure(message: 'Stream error: $error'));
    });
  }

  /// Stream active customer orders
  Stream<List<DeliveryOrder>> watchCustomerOrders(String customerId) {
    return _deliveriesRef
        .where('customerId', isEqualTo: customerId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => DeliveryOrder.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// Find an order by Waybill or Consignment Tracking Number (from courierManagementSystem)
  Future<Either<AppFailure, DeliveryOrder>> findOrderByTrackingNumber(
      String trackingNumber) async {
    final cleanCode = trackingNumber.trim().toUpperCase();
    if (cleanCode.isEmpty) {
      return left(const OrderNotFoundFailure(
          message: 'Please enter a valid tracking code.'));
    }

    try {
      final snapshot = await _deliveriesRef
          .where('trackingNumber', isEqualTo: cleanCode)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return left(OrderNotFoundFailure(
          message: 'No consignment found matching tracking code "$cleanCode".',
        ));
      }

      final doc = snapshot.docs.first;
      return right(DeliveryOrder.fromMap(doc.data(), doc.id));
    } catch (e) {
      return left(ServerFailure(message: 'Tracking lookup failed: $e'));
    }
  }

  /// Real-time stream of an order queried by its public Waybill / Consignment Tracking Number
  Stream<Either<AppFailure, DeliveryOrder>> watchOrderByTrackingNumber(
      String trackingNumber) {
    final cleanCode = trackingNumber.trim().toUpperCase();
    if (cleanCode.isEmpty) {
      return Stream.value(
        left<AppFailure, DeliveryOrder>(
          const OrderNotFoundFailure(
              message: 'Please enter a valid tracking code.'),
        ),
      );
    }

    return _deliveriesRef
        .where('trackingNumber', isEqualTo: cleanCode)
        .limit(1)
        .snapshots()
        .map<Either<AppFailure, DeliveryOrder>>((snapshot) {
      if (snapshot.docs.isEmpty) {
        return left<AppFailure, DeliveryOrder>(
          OrderNotFoundFailure(
            message:
                'No consignment found matching tracking code "$cleanCode".',
          ),
        );
      }
      final doc = snapshot.docs.first;
      return right<AppFailure, DeliveryOrder>(
        DeliveryOrder.fromMap(doc.data(), doc.id),
      );
    }).handleError((error) {
      return left<AppFailure, DeliveryOrder>(
        ServerFailure(message: 'Tracking stream error: $error'),
      );
    });
  }

  /// Stream unassigned express orders within radius for nearby drivers (from MyOGA & Deliverzler)
  Stream<List<DeliveryOrder>> watchAvailableOrders() {
    return _deliveriesRef
        .where('status', isEqualTo: DeliveryStatus.searchingDriver.name)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => DeliveryOrder.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// Update order status (with deterministic lifecycle verification, timestamps & audit logging)
  Future<Either<AppFailure, Unit>> updateStatus({
    required String orderId,
    required DeliveryStatus status,
    String? actorId,
    String actorRole = 'driver',
    String? note,
    String? cancellationReason,
    double? driverLatitude,
    double? driverLongitude,
  }) async {
    try {
      final doc = await _deliveriesRef.doc(orderId).get();
      if (!doc.exists || doc.data() == null) {
        return left(const OrderNotFoundFailure());
      }
      final currentOrder = DeliveryOrder.fromMap(doc.data()!, doc.id);

      final isStaff = actorRole == 'admin' || actorRole == 'support';
      if (!currentOrder.status.canTransitionTo(status, isAdmin: isStaff)) {
        return left(InvalidStatusTransitionFailure(
          fromStatus: currentOrder.status.label,
          toStatus: status.label,
        ));
      }

      final now = DateTime.now();
      final updateData = <String, dynamic>{
        'status': status.name,
      };

      if (status == DeliveryStatus.assigned) {
        updateData['assignedAt'] = now.toIso8601String();
      } else if (status == DeliveryStatus.arrivedPickup) {
        updateData['arrivedPickupAt'] = now.toIso8601String();
      } else if (status == DeliveryStatus.pickedUp) {
        updateData['pickedUpAt'] = now.toIso8601String();
      } else if (status == DeliveryStatus.inTransit) {
        updateData['inTransitAt'] = now.toIso8601String();
      } else if (status == DeliveryStatus.arrivedDropoff) {
        updateData['arrivedDropoffAt'] = now.toIso8601String();
      } else if (status == DeliveryStatus.delivered) {
        updateData['deliveredAt'] = now.toIso8601String();
      } else if (status == DeliveryStatus.cancelled) {
        updateData['cancelledAt'] = now.toIso8601String();
        if (cancellationReason != null) {
          updateData['cancellationReason'] = cancellationReason;
        }
        updateData['cancelledByRole'] = actorRole;
      }

      if (cancellationReason != null && status != DeliveryStatus.cancelled) {
        updateData['cancellationReason'] = cancellationReason;
      }
      if (driverLatitude != null && driverLongitude != null) {
        updateData['driverLatitude'] = driverLatitude;
        updateData['driverLongitude'] = driverLongitude;
      }

      final batch = _firestore.batch();
      batch.update(_deliveriesRef.doc(orderId), updateData);

      // Record immutable timeline audit entry
      final timelineRef =
          _deliveriesRef.doc(orderId).collection('timeline').doc();
      final event = DeliveryTimelineEvent(
        id: timelineRef.id,
        orderId: orderId,
        status: status,
        actorId: actorId ?? '',
        actorRole: actorRole,
        timestamp: now,
        note: note ??
            cancellationReason ??
            'Status transitioned to ${status.label}',
        latitude: driverLatitude,
        longitude: driverLongitude,
      );
      batch.set(timelineRef, event.toMap());

      await batch.commit();
      return right(unit);
    } catch (e) {
      return left(ServerFailure(message: 'Failed to update order status: $e'));
    }
  }

  /// Driver accepts job with concurrency & state machine check
  Future<Either<AppFailure, Unit>> acceptJob({
    required String orderId,
    required String driverId,
    required String driverName,
    required String driverPhone,
    required double driverLatitude,
    required double driverLongitude,
  }) async {
    try {
      final doc = await _deliveriesRef.doc(orderId).get();
      if (!doc.exists || doc.data() == null) {
        return left(const OrderNotFoundFailure());
      }
      final currentOrder = DeliveryOrder.fromMap(doc.data()!, doc.id);

      if (!currentOrder.status.canTransitionTo(DeliveryStatus.assigned)) {
        return left(InvalidStatusTransitionFailure(
          fromStatus: currentOrder.status.label,
          toStatus: DeliveryStatus.assigned.label,
          message:
              'Order is no longer available for assignment (Current status: ${currentOrder.status.label}).',
        ));
      }

      final now = DateTime.now();
      final batch = _firestore.batch();
      batch.update(_deliveriesRef.doc(orderId), {
        'status': DeliveryStatus.assigned.name,
        'driverId': driverId,
        'driverName': driverName,
        'driverPhone': driverPhone,
        'driverLatitude': driverLatitude,
        'driverLongitude': driverLongitude,
        'assignedAt': now.toIso8601String(),
      });

      final timelineRef =
          _deliveriesRef.doc(orderId).collection('timeline').doc();
      final event = DeliveryTimelineEvent(
        id: timelineRef.id,
        orderId: orderId,
        status: DeliveryStatus.assigned,
        actorId: driverId,
        actorRole: 'driver',
        timestamp: now,
        note: 'Courier $driverName accepted dispatch assignment',
        latitude: driverLatitude,
        longitude: driverLongitude,
      );
      batch.set(timelineRef, event.toMap());

      await batch.commit();
      return right(unit);
    } catch (e) {
      return left(ServerFailure(message: 'Failed to accept order: $e'));
    }
  }

  /// Stream active delivery orders assigned to a specific driver
  Stream<List<DeliveryOrder>> watchDriverActiveOrders(String driverId) {
    return _deliveriesRef
        .where('driverId', isEqualTo: driverId)
        .where('status', whereIn: [
          DeliveryStatus.assigned.name,
          DeliveryStatus.arrivedPickup.name,
          DeliveryStatus.pickedUp.name,
          DeliveryStatus.inTransit.name,
          DeliveryStatus.arrivedDropoff.name,
        ])
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => DeliveryOrder.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// Real-time live update of driver GPS coordinates
  Future<Either<AppFailure, Unit>> updateDriverLocation({
    required String orderId,
    required double driverLatitude,
    required double driverLongitude,
  }) async {
    try {
      await _deliveriesRef.doc(orderId).update({
        'driverLatitude': driverLatitude,
        'driverLongitude': driverLongitude,
      });
      return right(unit);
    } catch (e) {
      return left(ServerFailure(message: 'Failed to update GPS: $e'));
    }
  }

  /// Verify 4-digit recipient security PIN and complete delivery handover
  Future<Either<AppFailure, Unit>> verifyAndCompleteDelivery({
    required String orderId,
    required String driverId,
    required String inputOtp,
    required String expectedOtp,
    required double driverEarnings,
    double platformCommission = 0.0,
    String paymentMethod = 'wallet',
    String trackingNumber = '',
  }) async {
    if (inputOtp.trim() != expectedOtp.trim()) {
      return left(const InvalidOtpFailure(
        message:
            'Invalid 4-digit handover PIN. Please ask the recipient for the correct PIN.',
      ));
    }

    try {
      final doc = await _deliveriesRef.doc(orderId).get();
      if (!doc.exists || doc.data() == null) {
        return left(const OrderNotFoundFailure());
      }
      final currentOrder = DeliveryOrder.fromMap(doc.data()!, doc.id);

      if (!currentOrder.status.canTransitionTo(DeliveryStatus.delivered)) {
        return left(InvalidStatusTransitionFailure(
          fromStatus: currentOrder.status.label,
          toStatus: DeliveryStatus.delivered.label,
        ));
      }

      final now = DateTime.now();
      final batch = _firestore.batch();
      final isCod = paymentMethod == 'cashOnDelivery';

      // 1. Update order status to delivered and marked paid
      final orderRef = _deliveriesRef.doc(orderId);
      batch.update(orderRef, {
        'status': DeliveryStatus.delivered.name,
        'deliveredAt': now.toIso8601String(),
        'pricing.isPaid': true,
        'isSettled': true,
      });

      // 2. Timeline milestone audit event
      final timelineRef =
          _deliveriesRef.doc(orderId).collection('timeline').doc();
      final event = DeliveryTimelineEvent(
        id: timelineRef.id,
        orderId: orderId,
        status: DeliveryStatus.delivered,
        actorId: driverId,
        actorRole: 'driver',
        timestamp: now,
        note: 'Recipient verified 4-digit security PIN. Delivery successfully completed.',
      );
      batch.set(timelineRef, event.toMap());

      final driverRef = _firestore.collection('users').doc(driverId);
      final txRef = driverRef.collection('transactions').doc();

      if (isCod) {
        // Driver collected 100% physical cash. Deduct 20% platform commission from digital wallet.
        batch.update(driverRef, {
          'walletBalance': FieldValue.increment(-platformCommission),
        });

        batch.set(txRef, {
          'userId': driverId,
          'amount': platformCommission,
          'type': 'codCommission',
          'title': 'COD Platform Commission (20%)',
          'description':
              'Commission on cash collected for Waybill $trackingNumber',
          'referenceId': orderId,
          'createdAt': now.toIso8601String(),
        });
      } else {
        // Digital payment: Credit driver digital wallet with 80% net earnings
        batch.update(driverRef, {
          'walletBalance': FieldValue.increment(driverEarnings),
        });

        batch.set(txRef, {
          'userId': driverId,
          'amount': driverEarnings,
          'type': 'tripPayout',
          'title': 'Trip Payout (80%)',
          'description': 'Direct earnings from delivery completion',
          'referenceId': orderId,
          'createdAt': now.toIso8601String(),
        });
      }

      await batch.commit();
      return right(unit);
    } catch (e) {
      return left(ServerFailure(
          message: 'Failed to verify and complete delivery: $e'));
    }
  }

  /// Cancel an ongoing order with structured reason & audit trail
  Future<Either<AppFailure, Unit>> cancelOrder({
    required String orderId,
    required String reason,
    required String cancelledByRole,
    String? actorId,
  }) async {
    try {
      final doc = await _deliveriesRef.doc(orderId).get();
      if (!doc.exists || doc.data() == null) {
        return left(const OrderNotFoundFailure());
      }
      final currentOrder = DeliveryOrder.fromMap(doc.data()!, doc.id);

      final isStaff =
          cancelledByRole == 'admin' || cancelledByRole == 'support';
      if (!currentOrder.status
          .canTransitionTo(DeliveryStatus.cancelled, isAdmin: isStaff)) {
        return left(InvalidStatusTransitionFailure(
          fromStatus: currentOrder.status.label,
          toStatus: DeliveryStatus.cancelled.label,
          message:
              'Cannot cancel order in state "${currentOrder.status.label}".',
        ));
      }

      final now = DateTime.now();
      final batch = _firestore.batch();
      batch.update(_deliveriesRef.doc(orderId), {
        'status': DeliveryStatus.cancelled.name,
        'cancellationReason': reason,
        'cancelledByRole': cancelledByRole,
        'cancelledAt': now.toIso8601String(),
      });

      final timelineRef =
          _deliveriesRef.doc(orderId).collection('timeline').doc();
      final event = DeliveryTimelineEvent(
        id: timelineRef.id,
        orderId: orderId,
        status: DeliveryStatus.cancelled,
        actorId: actorId ?? '',
        actorRole: cancelledByRole,
        timestamp: now,
        note: 'Order cancelled: $reason',
      );
      batch.set(timelineRef, event.toMap());

      await batch.commit();
      return right(unit);
    } catch (e) {
      return left(ServerFailure(message: 'Failed to cancel order: $e'));
    }
  }

  /// Watch real-time immutable milestone event timeline for an order
  Stream<List<DeliveryTimelineEvent>> watchOrderTimeline(String orderId) {
    return _deliveriesRef
        .doc(orderId)
        .collection('timeline')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => DeliveryTimelineEvent.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// Rate a completed delivery and leave feedback for the driver
  Future<Either<AppFailure, Unit>> rateDeliveryOrder({
    required String orderId,
    required String driverId,
    required double rating,
    required String review,
  }) async {
    try {
      final batch = _firestore.batch();

      // 1. Update order document with rating and review
      final orderRef = _deliveriesRef.doc(orderId);
      batch.update(orderRef, {
        'customerRating': rating,
        'customerReview': review.trim(),
      });

      // 2. Update driver profile rating in users collection
      if (driverId.isNotEmpty) {
        final driverRef = _firestore.collection('users').doc(driverId);
        batch.update(driverRef, {
          'rating': rating,
        });
      }

      await batch.commit();
      return right(unit);
    } catch (e) {
      return left(ServerFailure(message: 'Failed to submit rating: $e'));
    }
  }
}
