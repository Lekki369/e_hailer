import 'package:e_hailer/features/admin/domain/entities/dispatch_metrics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DispatchMetrics Entity', () {
    test('default values are initialized correctly', () {
      const metrics = DispatchMetrics();
      expect(metrics.totalOrders, equals(0));
      expect(metrics.pendingAssignment, equals(0));
      expect(metrics.inTransit, equals(0));
      expect(metrics.deliveredToday, equals(0));
      expect(metrics.cancelled, equals(0));
      expect(metrics.onlineDrivers, equals(0));
      expect(metrics.totalDrivers, equals(0));
      expect(metrics.totalRevenueNgn, equals(0.0));
      expect(metrics.totalVolumeKg, equals(0.0));
    });

    test('copyWith properly updates operational metrics', () {
      const initial = DispatchMetrics();
      final updated = initial.copyWith(
        totalOrders: 25,
        pendingAssignment: 5,
        inTransit: 12,
        deliveredToday: 8,
        onlineDrivers: 7,
        totalRevenueNgn: 45000.0,
      );

      expect(updated.totalOrders, equals(25));
      expect(updated.pendingAssignment, equals(5));
      expect(updated.inTransit, equals(12));
      expect(updated.deliveredToday, equals(8));
      expect(updated.onlineDrivers, equals(7));
      expect(updated.totalRevenueNgn, equals(45000.0));
    });

    test('Equatable value equality verification', () {
      const metricsA = DispatchMetrics(totalOrders: 10, onlineDrivers: 3);
      const metricsB = DispatchMetrics(totalOrders: 10, onlineDrivers: 3);
      expect(metricsA, equals(metricsB));
    });
  });
}
