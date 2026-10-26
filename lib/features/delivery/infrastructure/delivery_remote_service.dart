import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/domain/failures/app_failure.dart';
import '../../../../core/presentation/utils/fp_framework.dart';
import '../domain/entities/delivery_order.dart';
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
      await docRef.set(finalOrder.toMap());
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

  /// Update order status (with optional driver GPS coords or notes)
  Future<Either<AppFailure, Unit>> updateStatus({
    required String orderId,
    required DeliveryStatus status,
    String? cancellationReason,
    double? driverLatitude,
    double? driverLongitude,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'status': status.name,
      };

      if (status == DeliveryStatus.pickedUp) {
        updateData['pickedUpAt'] = DateTime.now().toIso8601String();
      } else if (status == DeliveryStatus.delivered) {
        updateData['deliveredAt'] = DateTime.now().toIso8601String();
      }

      if (cancellationReason != null) {
        updateData['cancellationReason'] = cancellationReason;
      }
      if (driverLatitude != null && driverLongitude != null) {
        updateData['driverLatitude'] = driverLatitude;
        updateData['driverLongitude'] = driverLongitude;
      }

      await _deliveriesRef.doc(orderId).update(updateData);
      return right(unit);
    } catch (e) {
      return left(ServerFailure(message: 'Failed to update order status: $e'));
    }
  }

  /// Driver accepts job
  Future<Either<AppFailure, Unit>> acceptJob({
    required String orderId,
    required String driverId,
    required String driverName,
    required String driverPhone,
    required double driverLatitude,
    required double driverLongitude,
  }) async {
    try {
      await _deliveriesRef.doc(orderId).update({
        'status': DeliveryStatus.assigned.name,
        'driverId': driverId,
        'driverName': driverName,
        'driverPhone': driverPhone,
        'driverLatitude': driverLatitude,
        'driverLongitude': driverLongitude,
      });
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
        message: 'Invalid 4-digit handover PIN. Please ask the recipient for the correct PIN.',
      ));
    }

    try {
      final batch = _firestore.batch();
      final isCod = paymentMethod == 'cashOnDelivery';

      // 1. Update order status to delivered and marked paid
      final orderRef = _deliveriesRef.doc(orderId);
      batch.update(orderRef, {
        'status': DeliveryStatus.delivered.name,
        'deliveredAt': DateTime.now().toIso8601String(),
        'pricing.isPaid': true,
        'isSettled': true,
      });

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
          'createdAt': DateTime.now().toIso8601String(),
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
          'createdAt': DateTime.now().toIso8601String(),
        });
      }

      await batch.commit();
      return right(unit);
    } catch (e) {
      return left(ServerFailure(message: 'Failed to verify and complete delivery: $e'));
    }
  }

  /// Cancel an ongoing order with structured reason
  Future<Either<AppFailure, Unit>> cancelOrder({
    required String orderId,
    required String reason,
    required String cancelledByRole,
  }) async {
    try {
      await _deliveriesRef.doc(orderId).update({
        'status': DeliveryStatus.cancelled.name,
        'cancellationReason': reason,
        'cancelledByRole': cancelledByRole,
        'cancelledAt': DateTime.now().toIso8601String(),
      });
      return right(unit);
    } catch (e) {
      return left(ServerFailure(message: 'Failed to cancel order: $e'));
    }
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
