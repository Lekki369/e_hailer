import 'package:e_hailer/features/admin/domain/entities/operations_analytics.dart';
import 'package:e_hailer/features/delivery/domain/value_objects/delivery_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DriverPerformanceLeaderboardItem Entity', () {
    const item1 = DriverPerformanceLeaderboardItem(
      driverId: 'drv-001',
      driverName: 'Babatunde Fashola',
      phone: '+2348012345678',
      vehicleType: VehicleType.bike,
      rating: 4.9,
      completedDeliveries: 42,
      totalGrossVolumeNgn: 156000.0,
    );

    const item2 = DriverPerformanceLeaderboardItem(
      driverId: 'drv-001',
      driverName: 'Babatunde Fashola',
      phone: '+2348012345678',
      vehicleType: VehicleType.bike,
      rating: 4.9,
      completedDeliveries: 42,
      totalGrossVolumeNgn: 156000.0,
    );

    const item3 = DriverPerformanceLeaderboardItem(
      driverId: 'drv-002',
      driverName: 'Chidinma Okeke',
      phone: '+2348098765432',
      vehicleType: VehicleType.car,
      rating: 4.7,
      completedDeliveries: 28,
      totalGrossVolumeNgn: 112000.0,
    );

    test('instantiates with correct fields', () {
      expect(item1.driverId, equals('drv-001'));
      expect(item1.driverName, equals('Babatunde Fashola'));
      expect(item1.phone, equals('+2348012345678'));
      expect(item1.vehicleType, equals(VehicleType.bike));
      expect(item1.rating, equals(4.9));
      expect(item1.completedDeliveries, equals(42));
      expect(item1.totalGrossVolumeNgn, equals(156000.0));
    });

    test('props equality verification', () {
      expect(item1, equals(item2));
      expect(item1.hashCode, equals(item2.hashCode));
      expect(item1, isNot(equals(item3)));
    });
  });

  group('OperationsAnalytics Entity', () {
    test('default values are initialized correctly', () {
      const analytics = OperationsAnalytics();
      expect(analytics.totalOrders, equals(0));
      expect(analytics.completedOrders, equals(0));
      expect(analytics.failedOrCancelledOrders, equals(0));
      expect(analytics.inTransitOrders, equals(0));
      expect(analytics.pendingOrders, equals(0));
      expect(analytics.completionRate, equals(0.0));
      expect(analytics.failureRate, equals(0.0));
      expect(analytics.grossGmvNgn, equals(0.0));
      expect(analytics.platformCommissionNgn, equals(0.0));
      expect(analytics.driverPayoutsNgn, equals(0.0));
      expect(analytics.averageOrderValueNgn, equals(0.0));
      expect(analytics.totalCargoVolumeKg, equals(0.0));
      expect(analytics.codOrdersCount, equals(0));
      expect(analytics.digitalOrdersCount, equals(0));
      expect(analytics.vehicleBreakdown, isEmpty);
      expect(analytics.driverLeaderboard, isEmpty);
    });

    test('custom values and financial split are stored accurately', () {
      const item = DriverPerformanceLeaderboardItem(
        driverId: 'drv-001',
        driverName: 'Babatunde Fashola',
        phone: '+2348012345678',
        vehicleType: VehicleType.bike,
        rating: 4.9,
        completedDeliveries: 10,
        totalGrossVolumeNgn: 50000.0,
      );

      const analytics = OperationsAnalytics(
        totalOrders: 100,
        completedOrders: 85,
        failedOrCancelledOrders: 5,
        inTransitOrders: 8,
        pendingOrders: 2,
        completionRate: 85.0,
        failureRate: 5.0,
        grossGmvNgn: 500000.0,
        platformCommissionNgn: 100000.0,
        driverPayoutsNgn: 400000.0,
        averageOrderValueNgn: 5000.0,
        totalCargoVolumeKg: 450.5,
        codOrdersCount: 60,
        digitalOrdersCount: 40,
        vehicleBreakdown: {
          VehicleType.bike: 50,
          VehicleType.car: 30,
          VehicleType.van: 15,
          VehicleType.truck: 5,
        },
        driverLeaderboard: [item],
      );

      expect(analytics.totalOrders, equals(100));
      expect(analytics.completedOrders, equals(85));
      expect(analytics.failedOrCancelledOrders, equals(5));
      expect(analytics.inTransitOrders, equals(8));
      expect(analytics.pendingOrders, equals(2));
      expect(analytics.completionRate, equals(85.0));
      expect(analytics.failureRate, equals(5.0));
      expect(analytics.grossGmvNgn, equals(500000.0));
      expect(analytics.platformCommissionNgn, equals(100000.0));
      expect(analytics.driverPayoutsNgn, equals(400000.0));
      expect(analytics.averageOrderValueNgn, equals(5000.0));
      expect(analytics.totalCargoVolumeKg, equals(450.5));
      expect(analytics.codOrdersCount, equals(60));
      expect(analytics.digitalOrdersCount, equals(40));
      expect(analytics.vehicleBreakdown[VehicleType.bike], equals(50));
      expect(analytics.driverLeaderboard.length, equals(1));
      expect(analytics.driverLeaderboard.first.driverName, equals('Babatunde Fashola'));
    });

    test('Equatable value equality verification', () {
      const analyticsA = OperationsAnalytics(
        totalOrders: 50,
        grossGmvNgn: 250000.0,
      );
      const analyticsB = OperationsAnalytics(
        totalOrders: 50,
        grossGmvNgn: 250000.0,
      );
      const analyticsC = OperationsAnalytics(
        totalOrders: 75,
        grossGmvNgn: 375000.0,
      );

      expect(analyticsA, equals(analyticsB));
      expect(analyticsA.hashCode, equals(analyticsB.hashCode));
      expect(analyticsA, isNot(equals(analyticsC)));
    });
  });
}
