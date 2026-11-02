import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/infrastructure/operations_api.dart';
import '../../../../core/infrastructure/stream_result.dart';
import '../domain/dispatch_summary.dart';
import '../../../../core/domain/failures/app_failure.dart';
import '../../../../core/presentation/utils/fp_framework.dart';
import '../../delivery/domain/entities/delivery_order.dart';
import '../domain/entities/dispatch_metrics.dart';
import '../domain/entities/fleet_driver_summary.dart';

/// Remote service providing real-time data synchronization and manual dispatch operations
/// for Hub Dispatchers and Operations Administrators.
class AdminRemoteService {
  final FirebaseFirestore _firestore;
  final OperationsApi _api;

  AdminRemoteService({FirebaseFirestore? firestore, OperationsApi? api})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _api = api ?? OperationsApi();

  CollectionReference<Map<String, dynamic>> get _deliveriesRef =>
      _firestore.collection('deliveries');

  CollectionReference<Map<String, dynamic>> get _usersRef =>
      _firestore.collection('users');

  Stream<Either<AppFailure, List<DeliveryOrder>>> watchAllOrders() =>
      streamResult(
        _deliveriesRef.snapshots().map((snapshot) {
          final orders = snapshot.docs
              .map((doc) => DeliveryOrder.fromMap(doc.data(), doc.id))
              .toList();
          orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return orders;
        }),
      );

  Stream<Either<AppFailure, List<FleetDriverSummary>>> watchFleetDrivers() =>
      streamResult(
        _usersRef
            .where('role', isEqualTo: 'driver')
            .snapshots()
            .map(
              (snapshot) => snapshot.docs
                  .map((doc) => FleetDriverSummary.fromMap(doc.data(), doc.id))
                  .toList(),
            ),
      );

  Stream<Either<AppFailure, DispatchMetrics>> watchDispatchMetrics() =>
      watchAllOrders().map(
        (result) =>
            result.map((orders) => summarizeDispatch(orders, DateTime.now())),
      );

  /// Manually assign a driver to an order from the dispatch console.
  Future<Either<AppFailure, Unit>> assignDriverToOrder({
    required String orderId,
    required FleetDriverSummary driver,
  }) async {
    return batchAssignDriverToOrders(orderIds: [orderId], driver: driver);
  }

  /// Batch assign multiple orders to a designated fleet driver.
  Future<Either<AppFailure, Unit>> batchAssignDriverToOrders({
    required List<String> orderIds,
    required FleetDriverSummary driver,
  }) async {
    if (orderIds.isEmpty) return right(unit);
    return (await _api.execute('assignOrders', {
      'orderIds': orderIds,
      'driverId': driver.uid,
    })).map((_) => unit);
  }

  /// Reassign an existing delivery order to a new driver (e.g. if previous driver is delayed).
  Future<Either<AppFailure, Unit>> reassignDriver({
    required String orderId,
    required FleetDriverSummary newDriver,
    String? reason,
  }) async {
    return (await _api.execute('assignOrders', {
      'orderIds': [orderId],
      'driverId': newDriver.uid,
      'reason': ?reason,
    })).map((_) => unit);
  }

  /// Admin override to cancel an order with reason and audit trail.
  Future<Either<AppFailure, Unit>> cancelOrderByAdmin({
    required String orderId,
    required String reason,
  }) async {
    return (await _api.execute('cancelOrder', {
      'orderId': orderId,
      'reason': reason.trim(),
    })).map((_) => unit);
  }
}
