import 'package:e_hailer/features/admin/domain/entities/fleet_driver_summary.dart';
import 'package:e_hailer/features/delivery/domain/value_objects/delivery_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FleetDriverSummary Entity & Serialization', () {
    test('toMap and fromMap serialize and deserialize properly', () {
      final summary = FleetDriverSummary(
        uid: 'drv-001',
        fullName: 'Babatunde Ade',
        phone: '+2348011223344',
        email: 'babatunde@example.com',
        vehicleType: VehicleType.bike,
        vehiclePlateNumber: 'KJA-123-XY',
        vehicleModel: 'Honda Ace 125',
        isAvailable: true,
        rating: 4.8,
        currentOrderId: 'ord-999',
        lastKnownLatitude: 6.5244,
        lastKnownLongitude: 3.3792,
        lastActiveAt: DateTime(2026, 10, 26, 12, 0, 0),
      );

      final map = summary.toMap();
      final replica = FleetDriverSummary.fromMap(map, summary.uid);

      expect(replica.uid, equals(summary.uid));
      expect(replica.fullName, equals(summary.fullName));
      expect(replica.phone, equals(summary.phone));
      expect(replica.vehicleType, equals(VehicleType.bike));
      expect(replica.vehiclePlateNumber, equals('KJA-123-XY'));
      expect(replica.isAvailable, isTrue);
      expect(replica.rating, equals(4.8));
      expect(replica.currentOrderId, equals('ord-999'));
      expect(replica.lastKnownLatitude, equals(6.5244));
      expect(replica.lastKnownLongitude, equals(3.3792));
      expect(replica.lastActiveAt, equals(summary.lastActiveAt));
    });

    test('copyWith updates specified attributes immutably', () {
      const summary = FleetDriverSummary(
        uid: 'drv-002',
        fullName: 'Chidi Okonkwo',
        phone: '+2348099887766',
        email: 'chidi@example.com',
        isAvailable: false,
      );

      final updated = summary.copyWith(
        isAvailable: true,
        vehicleType: VehicleType.van,
        vehiclePlateNumber: 'LSR-456-AB',
      );

      expect(updated.isAvailable, isTrue);
      expect(updated.vehicleType, equals(VehicleType.van));
      expect(updated.vehiclePlateNumber, equals('LSR-456-AB'));
      expect(updated.fullName, equals(summary.fullName));
    });

    test('Equatable value equality verification', () {
      const driverA = FleetDriverSummary(
        uid: 'drv-1',
        fullName: 'Driver One',
        phone: '111',
        email: '1@test.com',
      );

      const driverB = FleetDriverSummary(
        uid: 'drv-1',
        fullName: 'Driver One',
        phone: '111',
        email: '1@test.com',
      );

      expect(driverA, equals(driverB));
    });
  });
}
