import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/domain/failures/app_failure.dart';
import '../../../../core/presentation/utils/fp_framework.dart';
import '../../delivery/domain/entities/delivery_order.dart';
import '../../delivery/domain/entities/delivery_timeline_event.dart';
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
      int assigned = 0;
      int active = 0;
      int delayed = 0;
      double revenue = 0.0;
      double volume = 0.0;

      for (final order in orders) {
        final isCompleted = order.status == DeliveryStatus.delivered ||
            order.status == DeliveryStatus.cancelled;
        if (!isCompleted) {
          active++;
        }
        if (order.driverId != null && !isCompleted) {
          assigned++;
        }
        if (order.isDelayed) {
          delayed++;
        }

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
        activeOrders: active,
        assignedOrders: assigned,
        unassignedOrders: pending,
        delayedOrders: delayed,
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
    return batchAssignDriverToOrders(
      orderIds: [orderId],
      driver: driver,
    );
  }

  /// Batch assign multiple orders to a designated fleet driver.
  Future<Either<AppFailure, Unit>> batchAssignDriverToOrders({
    required List<String> orderIds,
    required FleetDriverSummary driver,
  }) async {
    if (orderIds.isEmpty) {
      return right(unit);
    }
    try {
      final now = DateTime.now();
      final batch = _firestore.batch();

      for (final id in orderIds) {
        final orderDocRef = _deliveriesRef.doc(id);
        batch.update(orderDocRef, {
          'status': DeliveryStatus.assigned.name,
          'driverId': driver.uid,
          'driverName': driver.fullName,
          'driverPhone': driver.phone,
          'driverLatitude': driver.lastKnownLatitude,
          'driverLongitude': driver.lastKnownLongitude,
          'assignedAt': now.toIso8601String(),
        });

        final timelineRef = orderDocRef.collection('timeline').doc();
        final event = DeliveryTimelineEvent(
          id: timelineRef.id,
          orderId: id,
          status: DeliveryStatus.assigned,
          actorId: 'admin_dispatch',
          actorRole: 'admin',
          timestamp: now,
          note:
              'Manually assigned to driver ${driver.fullName} by Hub Dispatch',
          latitude: driver.lastKnownLatitude,
          longitude: driver.lastKnownLongitude,
        );
        batch.set(timelineRef, event.toMap());
      }

      final driverDocRef = _usersRef.doc(driver.uid);
      batch.update(driverDocRef, {
        'currentOrderId': orderIds.first,
      });

      await batch.commit();
      return right(unit);
    } catch (e) {
      return left(ServerFailure(message: 'Failed to batch assign orders: $e'));
    }
  }

  /// Reassign an existing delivery order to a new driver (e.g. if previous driver is delayed).
  Future<Either<AppFailure, Unit>> reassignDriver({
    required String orderId,
    required FleetDriverSummary newDriver,
    String? reason,
  }) async {
    try {
      final now = DateTime.now();
      final batch = _firestore.batch();

      final orderDocRef = _deliveriesRef.doc(orderId);
      final updateData = <String, dynamic>{
        'status': DeliveryStatus.assigned.name,
        'driverId': newDriver.uid,
        'driverName': newDriver.fullName,
        'driverPhone': newDriver.phone,
        'driverLatitude': newDriver.lastKnownLatitude,
        'driverLongitude': newDriver.lastKnownLongitude,
        'assignedAt': now.toIso8601String(),
      };
      if (reason != null && reason.trim().isNotEmpty) {
        updateData['reassignmentNote'] = reason.trim();
      }
      batch.update(orderDocRef, updateData);

      final timelineRef = orderDocRef.collection('timeline').doc();
      final event = DeliveryTimelineEvent(
        id: timelineRef.id,
        orderId: orderId,
        status: DeliveryStatus.assigned,
        actorId: 'admin_dispatch',
        actorRole: 'admin',
        timestamp: now,
        note: reason != null && reason.trim().isNotEmpty
            ? 'Reassigned to driver ${newDriver.fullName}. Reason: ${reason.trim()}'
            : 'Reassigned to driver ${newDriver.fullName} by Hub Dispatch',
        latitude: newDriver.lastKnownLatitude,
        longitude: newDriver.lastKnownLongitude,
      );
      batch.set(timelineRef, event.toMap());

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
      final now = DateTime.now();
      final batch = _firestore.batch();
      batch.update(_deliveriesRef.doc(orderId), {
        'status': DeliveryStatus.cancelled.name,
        'cancellationReason': reason.trim(),
        'cancelledByRole': 'admin',
        'cancelledAt': now.toIso8601String(),
      });

      final timelineRef =
          _deliveriesRef.doc(orderId).collection('timeline').doc();
      final event = DeliveryTimelineEvent(
        id: timelineRef.id,
        orderId: orderId,
        status: DeliveryStatus.cancelled,
        actorId: 'admin_dispatch',
        actorRole: 'admin',
        timestamp: now,
        note: 'Cancelled by Hub Dispatch: ${reason.trim()}',
      );
      batch.set(timelineRef, event.toMap());

      await batch.commit();
      return right(unit);
    } catch (e) {
      return left(ServerFailure(message: 'Failed to cancel order: $e'));
    }
  }
}
