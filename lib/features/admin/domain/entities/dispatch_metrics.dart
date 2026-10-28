import 'package:equatable/equatable.dart';

/// Aggregated real-time metrics for the admin dispatcher dashboard.
class DispatchMetrics extends Equatable {
  final int totalOrders;
  final int activeOrders;
  final int assignedOrders;
  final int unassignedOrders;
  final int delayedOrders;
  final int pendingAssignment; // Backwards-compatible alias for unassignedOrders
  final int inTransit;
  final int deliveredToday;
  final int cancelled;
  final int onlineDrivers;
  final int totalDrivers;
  final double totalRevenueNgn;
  final double totalVolumeKg;

  const DispatchMetrics({
    this.totalOrders = 0,
    this.activeOrders = 0,
    this.assignedOrders = 0,
    this.unassignedOrders = 0,
    this.delayedOrders = 0,
    this.pendingAssignment = 0,
    this.inTransit = 0,
    this.deliveredToday = 0,
    this.cancelled = 0,
    this.onlineDrivers = 0,
    this.totalDrivers = 0,
    this.totalRevenueNgn = 0.0,
    this.totalVolumeKg = 0.0,
  });

  DispatchMetrics copyWith({
    int? totalOrders,
    int? activeOrders,
    int? assignedOrders,
    int? unassignedOrders,
    int? delayedOrders,
    int? pendingAssignment,
    int? inTransit,
    int? deliveredToday,
    int? cancelled,
    int? onlineDrivers,
    int? totalDrivers,
    double? totalRevenueNgn,
    double? totalVolumeKg,
  }) {
    return DispatchMetrics(
      totalOrders: totalOrders ?? this.totalOrders,
      activeOrders: activeOrders ?? this.activeOrders,
      assignedOrders: assignedOrders ?? this.assignedOrders,
      unassignedOrders: unassignedOrders ?? this.unassignedOrders,
      delayedOrders: delayedOrders ?? this.delayedOrders,
      pendingAssignment: pendingAssignment ?? unassignedOrders ?? this.pendingAssignment,
      inTransit: inTransit ?? this.inTransit,
      deliveredToday: deliveredToday ?? this.deliveredToday,
      cancelled: cancelled ?? this.cancelled,
      onlineDrivers: onlineDrivers ?? this.onlineDrivers,
      totalDrivers: totalDrivers ?? this.totalDrivers,
      totalRevenueNgn: totalRevenueNgn ?? this.totalRevenueNgn,
      totalVolumeKg: totalVolumeKg ?? this.totalVolumeKg,
    );
  }

  @override
  List<Object?> get props => [
        totalOrders,
        activeOrders,
        assignedOrders,
        unassignedOrders,
        delayedOrders,
        pendingAssignment,
        inTransit,
        deliveredToday,
        cancelled,
        onlineDrivers,
        totalDrivers,
        totalRevenueNgn,
        totalVolumeKg,
      ];
}
