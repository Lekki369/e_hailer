import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/domain/failures/app_failure.dart';
import '../../../../core/presentation/utils/fp_framework.dart';
import '../../delivery/domain/entities/delivery_order.dart';
import '../../delivery/domain/value_objects/delivery_status.dart';
import '../domain/entities/dispatch_metrics.dart';
import '../domain/entities/fleet_driver_summary.dart';

/// Remote service providing real-time data synchronization and manual dispatch operations
/// for Hub Dispatchers and Operations Administrators.
class AdminRemoteService {
  final FirebaseFirestore _firestore;

  AdminRemoteService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _deliveriesRef =>
      _firestore.collection('deliveries');

  CollectionReference<Map<String, dynamic>> get _usersRef =>
      _firestore.collection('users');

  /// Real-time stream of all deliveries across the platform, newest first.
  Stream<List<DeliveryOrder>> watchAllOrders() {
    return _deliveriesRef
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => DeliveryOrder.fromMap(doc.data(), doc.id))
              .toList();
          // Sort newest first
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  /// Real-time stream of all registered fleet drivers.
  Stream<List<FleetDriverSummary>> watchFleetDrivers() {
    return _usersRef
        .where('role', isEqualTo: 'driver')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => FleetDriverSummary.fromMap(doc.data(), doc.id))
              .toList();
        });
  }

  /// Real-time aggregated operational metrics derived from orders and fleet drivers.
  Stream<DispatchMetrics> watchDispatchMetrics() {
    return watchAllOrders().map((orders) {
      int pending = 0;
      int inTransit = 0;
      int delivered = 0;
      int cancelled = 0;
      double revenue = 0.0;
      double volume = 0.0;

      for (final order in orders) {
        if (order.status == DeliveryStatus.created ||
            order.status == DeliveryStatus.searchingDriver) {
          pending++;
        } else if (order.status == DeliveryStatus.assigned ||
            order.status == DeliveryStatus.arrivedPickup ||
            order.status == DeliveryStatus.pickedUp ||
            order.status == DeliveryStatus.inTransit ||
            order.status == DeliveryStatus.arrivedDropoff) {
          inTransit++;
        } else if (order.status == DeliveryStatus.delivered) {
          delivered++;
        } else if (order.status == DeliveryStatus.cancelled) {
          cancelled++;
        }

        revenue += order.pricing.totalFare;
        volume += order.parcel.billableWeightKg;
      }

      return DispatchMetrics(
        totalOrders: orders.length,
        pendingAssignment: pending,
        inTransit: inTransit,
        deliveredToday: delivered,
        cancelled: cancelled,
        totalRevenueNgn: revenue,
        totalVolumeKg: volume,
      );
    });
  }

  /// Manually assign a driver to an order from the dispatch console.
  Future<Either<AppFailure, Unit>> assignDriverToOrder({
    required String orderId,
    required FleetDriverSummary driver,
  }) async {
    try {
      final batch = _firestore.batch();

      // 1. Update order document with driver info and assigned status
      final orderDocRef = _deliveriesRef.doc(orderId);
      batch.update(orderDocRef, {
        'status': DeliveryStatus.assigned.name,
        'driverId': driver.uid,
        'driverName': driver.fullName,
        'driverPhone': driver.phone,
        'driverLatitude': driver.lastKnownLatitude,
        'driverLongitude': driver.lastKnownLongitude,
      });

      // 2. Link current order to driver document
      final driverDocRef = _usersRef.doc(driver.uid);
      batch.update(driverDocRef, {
        'currentOrderId': orderId,
      });

      await batch.commit();
      return right(unit);
    } catch (e) {
      return left(ServerFailure(message: 'Failed to assign driver: $e'));
    }
  }

  /// Reassign an existing delivery order to a new driver (e.g. if previous driver is delayed).
  Future<Either<AppFailure, Unit>> reassignDriver({
    required String orderId,
    required FleetDriverSummary newDriver,
    String? reason,
  }) async {
    try {
      final batch = _firestore.batch();

      final orderDocRef = _deliveriesRef.doc(orderId);
      final updateData = <String, dynamic>{
        'status': DeliveryStatus.assigned.name,
        'driverId': newDriver.uid,
        'driverName': newDriver.fullName,
        'driverPhone': newDriver.phone,
        'driverLatitude': newDriver.lastKnownLatitude,
        'driverLongitude': newDriver.lastKnownLongitude,
      };
      if (reason != null && reason.trim().isNotEmpty) {
        updateData['reassignmentNote'] = reason.trim();
      }
      batch.update(orderDocRef, updateData);

      final driverDocRef = _usersRef.doc(newDriver.uid);
      batch.update(driverDocRef, {
        'currentOrderId': orderId,
      });

      await batch.commit();
      return right(unit);
    } catch (e) {
      return left(ServerFailure(message: 'Failed to reassign driver: $e'));
    }
  }

  /// Admin override to cancel an order with reason and audit trail.
  Future<Either<AppFailure, Unit>> cancelOrderByAdmin({
    required String orderId,
    required String reason,
  }) async {
    try {
      await _deliveriesRef.doc(orderId).update({
        'status': DeliveryStatus.cancelled.name,
        'cancellationReason': reason.trim(),
        'cancelledByRole': 'admin',
        'cancelledAt': DateTime.now().toIso8601String(),
      });
      return right(unit);
    } catch (e) {
      return left(ServerFailure(message: 'Failed to cancel order: $e'));
    }
  }
}
