import 'package:equatable/equatable.dart';

import '../../../delivery/domain/value_objects/delivery_type.dart';

/// Performance statistics for a fleet driver on the operational leaderboard
class DriverPerformanceLeaderboardItem extends Equatable {
  final String driverId;
  final String driverName;
  final String phone;
  final VehicleType vehicleType;
  final double rating;
  final int completedDeliveries;
  final double totalGrossVolumeNgn;

  const DriverPerformanceLeaderboardItem({
    required this.driverId,
    required this.driverName,
    required this.phone,
    required this.vehicleType,
    required this.rating,
    required this.completedDeliveries,
    required this.totalGrossVolumeNgn,
  });

  @override
  List<Object?> get props => [
        driverId,
        driverName,
        phone,
        vehicleType,
        rating,
        completedDeliveries,
        totalGrossVolumeNgn,
      ];
}

/// Comprehensive platform operations and business analytics metrics
class OperationsAnalytics extends Equatable {
  final int totalOrders;
  final int completedOrders;
  final int failedOrCancelledOrders;
  final int inTransitOrders;
  final int pendingOrders;
  final double completionRate; // 0.0 to 100.0%
  final double failureRate; // 0.0 to 100.0%
  final double onTimeRate; // 0.0 to 100.0%
  final double averageDeliveryTimeMinutes;
  final double grossGmvNgn; // Total Gross Merchandise Volume
  final double platformCommissionNgn; // 20% platform revenue cut
  final double driverPayoutsNgn; // 80% driver net earnings
  final double averageOrderValueNgn;
  final double totalCargoVolumeKg;
  final int codOrdersCount;
  final int digitalOrdersCount;
  final Map<VehicleType, int> vehicleBreakdown;
  final Map<String, int> zoneBreakdown;
  final Map<String, int> failureReasonBreakdown;
  final List<DriverPerformanceLeaderboardItem> driverLeaderboard;

  const OperationsAnalytics({
    this.totalOrders = 0,
    this.completedOrders = 0,
    this.failedOrCancelledOrders = 0,
    this.inTransitOrders = 0,
    this.pendingOrders = 0,
    this.completionRate = 0.0,
    this.failureRate = 0.0,
    this.onTimeRate = 100.0,
    this.averageDeliveryTimeMinutes = 0.0,
    this.grossGmvNgn = 0.0,
    this.platformCommissionNgn = 0.0,
    this.driverPayoutsNgn = 0.0,
    this.averageOrderValueNgn = 0.0,
    this.totalCargoVolumeKg = 0.0,
    this.codOrdersCount = 0,
    this.digitalOrdersCount = 0,
    this.vehicleBreakdown = const {},
    this.zoneBreakdown = const {},
    this.failureReasonBreakdown = const {},
    this.driverLeaderboard = const [],
  });

  @override
  List<Object?> get props => [
        totalOrders,
        completedOrders,
        failedOrCancelledOrders,
        inTransitOrders,
        pendingOrders,
        completionRate,
        failureRate,
        onTimeRate,
        averageDeliveryTimeMinutes,
        grossGmvNgn,
        platformCommissionNgn,
        driverPayoutsNgn,
        averageOrderValueNgn,
        totalCargoVolumeKg,
        codOrdersCount,
        digitalOrdersCount,
        vehicleBreakdown,
        zoneBreakdown,
        failureReasonBreakdown,
        driverLeaderboard,
      ];
}
