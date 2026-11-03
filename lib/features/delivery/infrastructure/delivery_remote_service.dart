import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/domain/failures/app_failure.dart';
import '../../../../core/infrastructure/operations_api.dart';
import '../../../../core/infrastructure/stream_result.dart';
import '../../../../core/presentation/utils/fp_framework.dart';
import '../domain/entities/delivery_order.dart';
import '../domain/entities/delivery_timeline_event.dart';
import '../domain/entities/public_delivery_tracking.dart';
import '../domain/value_objects/delivery_status.dart';

class DeliveryRemoteService {
  final FirebaseFirestore _firestore;
  final OperationsApi _api;
  DeliveryRemoteService({FirebaseFirestore? firestore, OperationsApi? api})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _api = api ?? OperationsApi();
  CollectionReference<Map<String, dynamic>> get _orders =>
      _firestore.collection('deliveries');

  Future<Either<AppFailure, Map<String, dynamic>>> quoteOrder(
    Map<String, dynamic> input,
  ) => _api.execute('quoteOrder', input);

  Future<Either<AppFailure, DeliveryOrder>> createOrder(
    Map<String, dynamic> input,
    String quoteId,
  ) async {
    final result = await _api.execute('createOrder', {
      ...input,
      'quoteId': quoteId,
    });
    try {
      return result.map(
        (data) => DeliveryOrder.fromMap(data, data['id'] as String),
      );
    } catch (_) {
      return left(
        const ServerFailure(
          message:
              'The booking response could not be read. Check your deliveries before retrying.',
        ),
      );
    }
  }

  Stream<Either<AppFailure, DeliveryOrder>> watchOrder(String orderId) async* {
    try {
      await for (final snapshot in _orders.doc(orderId).snapshots()) {
        final data = snapshot.data();
        yield data == null
            ? left(const OrderNotFoundFailure())
            : right(DeliveryOrder.fromMap(data, snapshot.id));
      }
    } catch (_) {
      yield left(
        const ServerFailure(
          message: 'Could not load this delivery. Please retry.',
        ),
      );
    }
  }

  Stream<Either<AppFailure, List<DeliveryOrder>>> _watchOrders(
    Query<Map<String, dynamic>> query,
  ) => streamResult(
    query.snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => DeliveryOrder.fromMap(doc.data(), doc.id))
          .toList(),
    ),
  );
  Stream<Either<AppFailure, List<DeliveryOrder>>> watchCustomerOrders(
    String customerId,
  ) => _watchOrders(_orders.where('customerId', isEqualTo: customerId));
  Stream<Either<AppFailure, List<DeliveryOrder>>> watchAvailableOrders(
    String vehicleType,
    List<String> serviceAreaIds,
  ) => _watchOrders(
    _firestore
        .collection('jobOffers')
        .where('vehicleType', isEqualTo: vehicleType)
        .where('serviceAreaId', whereIn: serviceAreaIds)
        .limit(30),
  );
  Stream<Either<AppFailure, List<DeliveryOrder>>> watchDriverActiveOrders(
    String driverId,
  ) => _watchOrders(_orders.where('driverId', isEqualTo: driverId)).map(
    (result) => result.map(
      (orders) => orders.where((o) => o.status.isOngoing).toList(),
    ),
  );

  Stream<Either<AppFailure, PublicDeliveryTracking>> watchOrderByTrackingNumber(
    String code,
  ) async* {
    final clean = code.trim().toUpperCase();
    if (!RegExp(r'^EH-[A-F0-9]{32}$').hasMatch(clean)) {
      yield left(
        const OrderNotFoundFailure(
          message: 'Enter the complete tracking code from your receipt.',
        ),
      );
      return;
    }
    try {
      await for (final snapshot
          in _firestore.collection('publicTracking').doc(clean).snapshots()) {
        final data = snapshot.data();
        yield data == null
            ? left(const OrderNotFoundFailure())
            : right(PublicDeliveryTracking.fromMap(data));
      }
    } catch (_) {
      yield left(
        const ServerFailure(
          message:
              'Tracking is unavailable or this link has expired. Please retry or contact the sender.',
        ),
      );
    }
  }

  Stream<Either<AppFailure, String?>> watchRecipientPin(String orderId) =>
      streamResult(
        _firestore
            .collection('deliveryPins')
            .doc(orderId)
            .snapshots()
            .map((doc) => doc.data()?['pin'] as String?),
      );

  Future<Either<AppFailure, Unit>> _send(
    String command,
    Map<String, dynamic> data,
  ) async => (await _api.execute(command, data)).map((_) => unit);

  Future<Either<AppFailure, Unit>> updateStatus({
    required String orderId,
    required DeliveryStatus status,
    String? actorId,
    String actorRole = 'driver',
    String? note,
    String? cancellationReason,
    double? driverLatitude,
    double? driverLongitude,
  }) => _send('updateStatus', {'orderId': orderId, 'status': status.name});
  Future<Either<AppFailure, Unit>> acceptJob({
    required String orderId,
    required String driverId,
    required String driverName,
    required String driverPhone,
    required double driverLatitude,
    required double driverLongitude,
  }) => _send('acceptJob', {'orderId': orderId});
  Future<Either<AppFailure, Unit>> updateDriverLocation({
    required String orderId,
    required double driverLatitude,
    required double driverLongitude,
  }) => _send('updateDriverLocation', {
    'orderId': orderId,
    'driverLatitude': driverLatitude,
    'driverLongitude': driverLongitude,
  });
  Future<Either<AppFailure, Unit>> verifyAndCompleteDelivery({
    required String orderId,
    required String inputOtp,
  }) => _send('completeDelivery', {'orderId': orderId, 'pin': inputOtp.trim()});
  Future<Either<AppFailure, Unit>> cancelOrder({
    required String orderId,
    required String reason,
    required String cancelledByRole,
    String? actorId,
  }) => _send('cancelOrder', {'orderId': orderId, 'reason': reason.trim()});
  Future<Either<AppFailure, Unit>> rateDeliveryOrder({
    required String orderId,
    required String driverId,
    required double rating,
    required String review,
  }) => _send('rateDelivery', {
    'orderId': orderId,
    'rating': rating,
    'review': review.trim(),
  });
  Stream<Either<AppFailure, List<DeliveryTimelineEvent>>> watchOrderTimeline(
    String orderId,
  ) => streamResult(
    _orders
        .doc(orderId)
        .collection('timeline')
        .orderBy('timestamp')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => DeliveryTimelineEvent.fromMap(doc.data(), doc.id))
              .toList(),
        ),
  );
}
