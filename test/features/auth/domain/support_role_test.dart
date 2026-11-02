import 'package:flutter_test/flutter_test.dart';
import 'package:e_hailer/features/auth/domain/user_entity.dart';

void main() {
  group('UserRole & Support Role RBAC Tests', () {
    test('UserRole.fromString parses support role case-insensitively', () {
      expect(UserRole.fromString('support'), UserRole.support);
      expect(UserRole.fromString('SUPPORT'), UserRole.support);
      expect(UserRole.fromString('Support'), UserRole.support);
    });

    test('UserRole role boolean helpers classify access accurately', () {
      const support = UserRole.support;
      expect(support.isSupport, isTrue);
      expect(support.isStaff, isTrue);
      expect(support.isAdmin, isFalse);
      expect(support.isDriver, isFalse);
      expect(support.isCustomer, isFalse);

      const admin = UserRole.admin;
      expect(admin.isAdmin, isTrue);
      expect(admin.isStaff, isTrue);
      expect(admin.isSupport, isFalse);

      const customer = UserRole.customer;
      expect(customer.isCustomer, isTrue);
      expect(customer.isStaff, isFalse);

      const driver = UserRole.driver;
      expect(driver.isDriver, isTrue);
      expect(driver.isStaff, isFalse);
    });

    test('UserEntity with support role preserves role and serialization', () {
      final user = UserEntity(
        uid: 'SUPP-001',
        email: 'officer@ehailer.com',
        fullName: 'Support Agent Jane',
        phone: '+2348011223344',
        role: UserRole.support,
        walletBalance: 0.0,
        rating: 5.0,
        createdAt: DateTime(2026, 1, 1),
      );

      final map = user.toMap();
      expect(map['role'], 'support');

      final restored = UserEntity.fromMap(map, 'SUPP-001');
      expect(restored.role, UserRole.support);
      expect(restored.role.isStaff, isTrue);
    });
  });
}
