import 'package:flutter_test/flutter_test.dart';
import 'package:e_hailer/features/auth/domain/user_entity.dart';
import 'package:e_hailer/features/delivery/domain/value_objects/delivery_type.dart';

void main() {
  group('UserRole Enum', () {
    test('fromString parses roles correctly with fallback', () {
      expect(UserRole.fromString('customer'), equals(UserRole.customer));
      expect(UserRole.fromString('DRIVER'), equals(UserRole.driver));
      expect(UserRole.fromString('admin'), equals(UserRole.admin));
      expect(UserRole.fromString('nonexistent'), equals(UserRole.customer));
      expect(UserRole.fromString(null), equals(UserRole.customer));
    });
  });

  group('UserEntity', () {
    final now = DateTime(2026, 10, 26, 10, 0, 0);

    final customer = UserEntity(
      uid: 'user_cust_1',
      role: UserRole.customer,
      fullName: 'Aisha Bello',
      email: 'aisha@example.com',
      phone: '+2348033334444',
      walletBalance: 25000.0,
      createdAt: now,
    );

    final driver = UserEntity(
      uid: 'user_drv_1',
      role: UserRole.driver,
      fullName: 'Tunde Adeleke',
      email: 'tunde@example.com',
      phone: '+2348022223333',
      walletBalance: 8500.0,
      rating: 4.9,
      isAvailable: true,
      vehicleType: VehicleType.bike,
      vehiclePlateNumber: 'KJA-123XY',
      vehicleModel: 'Bajaj Boxer 150',
      createdAt: now,
    );

    test('Customer serialization toMap and fromMap works seamlessly', () {
      final map = customer.toMap();
      final restored = UserEntity.fromMap(map);

      expect(restored, equals(customer));
      expect(restored.role, equals(UserRole.customer));
      expect(restored.walletBalance, equals(25000.0));
      expect(restored.vehicleType, isNull);
    });

    test('Driver serialization preserves fleet vehicle attributes', () {
      final map = driver.toMap();
      final restored = UserEntity.fromMap(map);

      expect(restored, equals(driver));
      expect(restored.role, equals(UserRole.driver));
      expect(restored.isAvailable, isTrue);
      expect(restored.vehicleType, equals(VehicleType.bike));
      expect(restored.vehiclePlateNumber, equals('KJA-123XY'));
      expect(restored.vehicleModel, equals('Bajaj Boxer 150'));
    });

    test('fromMap uses optional docId when provided', () {
      final map = customer.toMap();
      map.remove('uid');
      final restored = UserEntity.fromMap(map, 'override_uid_99');

      expect(restored.uid, equals('override_uid_99'));
    });

    test('copyWith modifies state immutably', () {
      final updatedDriver = driver.copyWith(
        walletBalance: 12000.0,
        isAvailable: false,
        vehicleType: VehicleType.car,
        vehicleModel: 'Toyota Corolla 2018',
      );

      expect(updatedDriver.walletBalance, equals(12000.0));
      expect(updatedDriver.isAvailable, isFalse);
      expect(updatedDriver.vehicleType, equals(VehicleType.car));
      expect(updatedDriver.vehicleModel, equals('Toyota Corolla 2018'));
      expect(updatedDriver.vehiclePlateNumber, equals(driver.vehiclePlateNumber)); // Intact
    });

    test('Equatable equality verification', () {
      final customerClone = UserEntity(
        uid: 'user_cust_1',
        role: UserRole.customer,
        fullName: 'Aisha Bello',
        email: 'aisha@example.com',
        phone: '+2348033334444',
        walletBalance: 25000.0,
        createdAt: now,
      );

      expect(customer, equals(customerClone));
      expect(customer == driver, isFalse);
    });
  });
}
