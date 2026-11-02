import '../../delivery/domain/entities/delivery_order.dart';
import '../../delivery/domain/value_objects/delivery_status.dart';
import 'entities/dispatch_metrics.dart';

/// Daily fulfillment/revenue alongside the current active workload.
DispatchMetrics summarizeDispatch(List<DeliveryOrder> orders, DateTime now) {
  var pending = 0,
      transit = 0,
      deliveredToday = 0,
      cancelled = 0,
      assigned = 0,
      active = 0,
      delayed = 0;
  var revenueToday = 0.0, volume = 0.0;
  final localNow = now.toLocal();
  for (final order in orders) {
    if (order.status.isOngoing) {
      active++;
      if (order.driverId != null) assigned++;
      if (order.isDelayed) delayed++;
    }
    if ({
      DeliveryStatus.created,
      DeliveryStatus.searchingDriver,
    }.contains(order.status)) {
      pending++;
    } else if (order.status.isOngoing) {
      transit++;
    } else if (order.status == DeliveryStatus.cancelled) {
      cancelled++;
    }
    final completed = order.deliveredAt?.toLocal();
    final today =
        completed != null &&
        completed.year == localNow.year &&
        completed.month == localNow.month &&
        completed.day == localNow.day;
    if (order.status == DeliveryStatus.delivered && today) {
      deliveredToday++;
      if (order.isSettled && order.pricing.isPaid) {
        revenueToday += (order.pricing.totalFare - order.refundedAmount).clamp(
          0,
          double.infinity,
        );
      }
    }
    volume += order.parcel.billableWeightKg;
  }
  return DispatchMetrics(
    totalOrders: orders.length,
    activeOrders: active,
    assignedOrders: assigned,
    unassignedOrders: pending,
    delayedOrders: delayed,
    pendingAssignment: pending,
    inTransit: transit,
    deliveredToday: deliveredToday,
    cancelled: cancelled,
    totalRevenueNgn: revenueToday,
    totalVolumeKg: volume,
  );
}
