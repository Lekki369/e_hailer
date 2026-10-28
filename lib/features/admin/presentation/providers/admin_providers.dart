import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../delivery/domain/entities/delivery_order.dart';
import '../../../delivery/domain/value_objects/delivery_status.dart';
import '../../domain/entities/dispatch_metrics.dart';
import '../../domain/entities/fleet_driver_summary.dart';
import '../../infrastructure/admin_remote_service.dart';

/// Provider for AdminRemoteService instance
final adminRemoteServiceProvider = Provider<AdminRemoteService>((ref) {
  return AdminRemoteService();
});

/// Stream of all system orders, sorted by newest first
final allOrdersStreamProvider = StreamProvider<List<DeliveryOrder>>((ref) {
  final service = ref.watch(adminRemoteServiceProvider);
  return service.watchAllOrders();
});

/// Stream of all registered fleet drivers
final fleetDriversStreamProvider =
    StreamProvider<List<FleetDriverSummary>>((ref) {
  final service = ref.watch(adminRemoteServiceProvider);
  return service.watchFleetDrivers();
});

/// Stream of online fleet drivers (currently available for dispatch)
final onlineFleetDriversProvider = Provider<List<FleetDriverSummary>>((ref) {
  final driversAsync = ref.watch(fleetDriversStreamProvider);
  return driversAsync.maybeWhen(
    data: (drivers) => drivers.where((d) => d.isAvailable).toList(),
    orElse: () => [],
  );
});

/// Real-time stream of platform dispatch metrics
final dispatchMetricsStreamProvider = StreamProvider<DispatchMetrics>((ref) {
  final service = ref.watch(adminRemoteServiceProvider);
  final onlineDrivers = ref.watch(onlineFleetDriversProvider).length;
  final totalDrivers = ref
      .watch(fleetDriversStreamProvider)
      .maybeWhen(data: (d) => d.length, orElse: () => 0);

  return service.watchDispatchMetrics().map((metrics) {
    return metrics.copyWith(
      onlineDrivers: onlineDrivers,
      totalDrivers: totalDrivers,
    );
  });
});

/// Notifier for filtering the dispatch queue by DeliveryStatus (null = all)
class OrderStatusFilterNotifier extends Notifier<DeliveryStatus?> {
  @override
  DeliveryStatus? build() => null;

  @override
  set state(DeliveryStatus? value) => super.state = value;
}

final orderStatusFilterProvider =
    NotifierProvider<OrderStatusFilterNotifier, DeliveryStatus?>(
  OrderStatusFilterNotifier.new,
);

/// Notifier for live search query (Waybill tracking number, customer phone, name)
class OrderSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  @override
  set state(String value) => super.state = value;
}

final orderSearchQueryProvider =
    NotifierProvider<OrderSearchQueryNotifier, String>(
  OrderSearchQueryNotifier.new,
);

/// Sort options for the dispatch queue
enum QueueSortOption {
  priority('Priority & Urgency'),
  newest('Newest First'),
  oldest('Oldest First'),
  zone('Pickup Zone');

  final String label;
  const QueueSortOption(this.label);
}

class QueueSortOptionNotifier extends Notifier<QueueSortOption> {
  @override
  QueueSortOption build() => QueueSortOption.priority;

  @override
  set state(QueueSortOption value) => super.state = value;
}

final queueSortOptionProvider =
    NotifierProvider<QueueSortOptionNotifier, QueueSortOption>(
  QueueSortOptionNotifier.new,
);

class DelayedFilterNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  @override
  set state(bool value) => super.state = value;
}

final delayedFilterProvider =
    NotifierProvider<DelayedFilterNotifier, bool>(
  DelayedFilterNotifier.new,
);

/// Computed provider returning filtered orders according to active status filter, delayed filter, and search query
final filteredOrdersProvider = Provider<List<DeliveryOrder>>((ref) {
  final ordersAsync = ref.watch(allOrdersStreamProvider);
  final statusFilter = ref.watch(orderStatusFilterProvider);
  final delayedOnly = ref.watch(delayedFilterProvider);
  final sortOption = ref.watch(queueSortOptionProvider);
  final query = ref.watch(orderSearchQueryProvider).trim().toLowerCase();

  return ordersAsync.maybeWhen(
    data: (orders) {
      final list = orders.where((order) {
        // Delayed only filter
        if (delayedOnly && !order.isDelayed) {
          return false;
        }

        // Status matching
        if (statusFilter != null && order.status != statusFilter) {
          return false;
        }

        // Search text matching (Tracking number, customer name, phone, or address)
        if (query.isNotEmpty) {
          final matchesTracking =
              order.trackingNumber.toLowerCase().contains(query);
          final matchesName =
              order.customerName.toLowerCase().contains(query);
          final matchesPhone =
              order.customerPhone.toLowerCase().contains(query);
          final matchesPickup =
              order.pickupLocation.address.toLowerCase().contains(query);
          final matchesDropoff =
              order.dropoffLocation.address.toLowerCase().contains(query);

          if (!matchesTracking &&
              !matchesName &&
              !matchesPhone &&
              !matchesPickup &&
              !matchesDropoff) {
            return false;
          }
        }

        return true;
      }).toList();

      // Apply sorting
      switch (sortOption) {
        case QueueSortOption.priority:
          list.sort((a, b) => b.priorityScore.compareTo(a.priorityScore));
          break;
        case QueueSortOption.newest:
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          break;
        case QueueSortOption.oldest:
          list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
          break;
        case QueueSortOption.zone:
          list.sort((a, b) => a.pickupZone.compareTo(b.pickupZone));
          break;
      }

      return list;
    },
    orElse: () => [],
  );
});
