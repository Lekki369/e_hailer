import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../delivery/domain/entities/pricing_details.dart';
import '../../../delivery/domain/value_objects/delivery_status.dart';
import '../../../delivery/domain/value_objects/delivery_type.dart';
import '../../domain/entities/operations_analytics.dart';
import 'admin_providers.dart';

/// Available time windows for operational analytics reporting
enum AnalyticsTimeRange {
  today('Today'),
  thisWeek('Past 7 Days'),
  thisMonth('Past 30 Days'),
  allTime('All Time');

  final String label;
  const AnalyticsTimeRange(this.label);
}

/// Filter provider for selected analytics time range
final analyticsTimeRangeProvider =
    StateProvider<AnalyticsTimeRange>((ref) => AnalyticsTimeRange.allTime);

/// Provider synthesizing real-time operational metrics, financial split, and driver performance
final operationsAnalyticsProvider =
    Provider<AsyncValue<OperationsAnalytics>>((ref) {
  final allOrdersAsync = ref.watch(allOrdersStreamProvider);
  final fleetDriversAsync = ref.watch(fleetDriversStreamProvider);
  final timeRange = ref.watch(analyticsTimeRangeProvider);

  if (allOrdersAsync.isLoading || fleetDriversAsync.isLoading) {
    return const AsyncValue.loading();
  }

  if (allOrdersAsync.hasError) {
    return AsyncValue.error(
      allOrdersAsync.error!,
      allOrdersAsync.stackTrace ?? StackTrace.current,
    );
  }

  final orders = allOrdersAsync.value ?? [];
  final drivers = fleetDriversAsync.value ?? [];
  final now = DateTime.now();

  // 1. Time range filter
  final filteredOrders = orders.where((order) {
    switch (timeRange) {
      case AnalyticsTimeRange.today:
        return order.createdAt.year == now.year &&
            order.createdAt.month == now.month &&
            order.createdAt.day == now.day;
      case AnalyticsTimeRange.thisWeek:
        return order.createdAt.isAfter(now.subtract(const Duration(days: 7)));
      case AnalyticsTimeRange.thisMonth:
        return order.createdAt.isAfter(now.subtract(const Duration(days: 30)));
      case AnalyticsTimeRange.allTime:
        return true;
    }
  }).toList();

  final totalOrders = filteredOrders.length;
  int completed = 0;
  int failedOrCancelled = 0;
  int inTransit = 0;
  int pending = 0;
  double grossGmv = 0.0;
  double totalVolume = 0.0;
  int codCount = 0;
  int digitalCount = 0;

  final Map<VehicleType, int> vehicleMap = {
    VehicleType.bike: 0,
    VehicleType.car: 0,
    VehicleType.van: 0,
    VehicleType.truck: 0,
  };

  final Map<String, int> driverTripCounts = {};
  final Map<String, double> driverGrossFares = {};

  for (final order in filteredOrders) {
    // Fulfillment statuses
    if (order.status == DeliveryStatus.delivered) {
      completed++;
    } else if (order.status == DeliveryStatus.cancelled ||
        order.status == DeliveryStatus.failedDelivery ||
        order.status == DeliveryStatus.returnedToHub) {
      failedOrCancelled++;
    } else if (order.status == DeliveryStatus.inTransit ||
        order.status == DeliveryStatus.pickedUp ||
        order.status == DeliveryStatus.arrivedDropoff) {
      inTransit++;
    } else {
      pending++;
    }

    grossGmv += order.pricing.totalFare;
    totalVolume += order.parcel.billableWeightKg;

    // Payment split
    if (order.pricing.paymentMethod == PaymentMethod.cashOnDelivery) {
      codCount++;
    } else {
      digitalCount++;
    }

    // Vehicle breakdown
    vehicleMap[order.vehicleType] = (vehicleMap[order.vehicleType] ?? 0) + 1;

    // Driver leaderboard aggregation (delivered trips)
    if (order.status == DeliveryStatus.delivered && order.driverId != null) {
      final dId = order.driverId!;
      driverTripCounts[dId] = (driverTripCounts[dId] ?? 0) + 1;
      driverGrossFares[dId] =
          (driverGrossFares[dId] ?? 0.0) + order.pricing.totalFare;
    }
  }

  // Driver leaderboard generation
  final leaderboardItems = <DriverPerformanceLeaderboardItem>[];
  for (final driver in drivers) {
    final completedCount = driverTripCounts[driver.uid] ?? 0;
    final grossVolume = driverGrossFares[driver.uid] ?? 0.0;

    leaderboardItems.add(
      DriverPerformanceLeaderboardItem(
        driverId: driver.uid,
        driverName: driver.fullName,
        phone: driver.phone,
        vehicleType: driver.vehicleType,
        rating: driver.rating,
        completedDeliveries: completedCount,
        totalGrossVolumeNgn: grossVolume,
      ),
    );
  }

  // Sort by completed deliveries descending
  leaderboardItems.sort(
    (a, b) => b.completedDeliveries.compareTo(a.completedDeliveries),
  );

  final completionRate =
      totalOrders > 0 ? (completed / totalOrders) * 100.0 : 0.0;
  final failureRate =
      totalOrders > 0 ? (failedOrCancelled / totalOrders) * 100.0 : 0.0;
  final aov = totalOrders > 0 ? grossGmv / totalOrders : 0.0;

  final analytics = OperationsAnalytics(
    totalOrders: totalOrders,
    completedOrders: completed,
    failedOrCancelledOrders: failedOrCancelled,
    inTransitOrders: inTransit,
    pendingOrders: pending,
    completionRate: completionRate,
    failureRate: failureRate,
    grossGmvNgn: grossGmv,
    platformCommissionNgn: grossGmv * 0.20,
    driverPayoutsNgn: grossGmv * 0.80,
    averageOrderValueNgn: aov,
    totalCargoVolumeKg: totalVolume,
    codOrdersCount: codCount,
    digitalOrdersCount: digitalCount,
    vehicleBreakdown: vehicleMap,
    driverLeaderboard: leaderboardItems.take(5).toList(),
  );

  return AsyncValue.data(analytics);
});
