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
  }) async {
    if (inputOtp.trim() != expectedOtp.trim()) {
      return left(const InvalidOtpFailure(
        message: 'Invalid 4-digit handover PIN. Please ask the recipient for the correct PIN.',
      ));
    }

    try {
      final batch = _firestore.batch();

      // 1. Update order status to delivered
      final orderRef = _deliveriesRef.doc(orderId);
      batch.update(orderRef, {
        'status': DeliveryStatus.delivered.name,
        'deliveredAt': DateTime.now().toIso8601String(),
      });

      // 2. Credit driver digital wallet with 80% net earnings
      final driverRef = _firestore.collection('users').doc(driverId);
      batch.update(driverRef, {
        'walletBalance': FieldValue.increment(driverEarnings),
      });

      // 3. Record driver trip payout in ledger
      final txRef = driverRef.collection('transactions').doc();
      batch.set(txRef, {
        'userId': driverId,
        'amount': driverEarnings,
        'type': 'tripPayout',
        'title': 'Trip Payout (80%)',
        'description': 'Direct earnings from delivery completion',
        'referenceId': orderId,
        'createdAt': DateTime.now().toIso8601String(),
      });

      await batch.commit();
      return right(unit);
    } catch (e) {
      return left(ServerFailure(message: 'Failed to verify and complete delivery: $e'));
    }
  }
}
