import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../../core/domain/failures/app_failure.dart';
import '../../../../core/presentation/utils/fp_framework.dart';
import '../../domain/entities/delivery_order.dart';
import '../../infrastructure/delivery_remote_service.dart';

/// Provider for Delivery Remote Service
final deliveryRemoteServiceProvider = Provider<DeliveryRemoteService>((ref) {
  return DeliveryRemoteService();
});

/// Stream provider for an individual order by ID
final activeOrderStreamProvider =
    StreamProvider.family<Either<AppFailure, DeliveryOrder>, String>(
        (ref, orderId) {
  final service = ref.watch(deliveryRemoteServiceProvider);
  return service.watchOrder(orderId);
});

/// Stream provider for available pending orders (for driver app)
final availableOrdersStreamProvider =
    StreamProvider<List<DeliveryOrder>>((ref) {
  final service = ref.watch(deliveryRemoteServiceProvider);
  return service.watchAvailableOrders();
});

/// Stream provider for customer orders
final customerOrdersStreamProvider =
    StreamProvider.family<List<DeliveryOrder>, String>((ref, customerId) {
  final service = ref.watch(deliveryRemoteServiceProvider);
  return service.watchCustomerOrders(customerId);
});

/// Stream provider for driver's active ongoing orders
final driverActiveOrdersStreamProvider =
    StreamProvider.family<List<DeliveryOrder>, String>((ref, driverId) {
  final service = ref.watch(deliveryRemoteServiceProvider);
  return service.watchDriverActiveOrders(driverId);
});
