import 'package:flutter_test/flutter_test.dart';
import 'package:e_hailer/features/delivery/domain/entities/pricing_details.dart';

void main() {
  group('PricingDetails Entity', () {
    test('PaymentMethod.fromString correctly resolves values with fallback', () {
      expect(PaymentMethod.fromString('wallet'), equals(PaymentMethod.wallet));
      expect(PaymentMethod.fromString('CARD'), equals(PaymentMethod.card));
      expect(PaymentMethod.fromString('cashOnDelivery'), equals(PaymentMethod.cashOnDelivery));
      expect(PaymentMethod.fromString('invalid_method'), equals(PaymentMethod.wallet));
      expect(PaymentMethod.fromString(null), equals(PaymentMethod.wallet));
    });

    test('toMap and fromMap serialize and deserialize accurately', () {
      const original = PricingDetails(
        baseFare: 500.0,
        distanceFare: 600.0,
        weightSurcharge: 240.0,
        totalFare: 1340.0,
        currency: 'NGN',
        paymentMethod: PaymentMethod.wallet,
        isPaid: true,
        driverEarnings: 1072.0,
        platformCommission: 268.0,
      );

      final map = original.toMap();
      final restored = PricingDetails.fromMap(map);

      expect(restored, equals(original));
      expect(restored.baseFare, equals(500.0));
      expect(restored.distanceFare, equals(600.0));
      expect(restored.weightSurcharge, equals(240.0));
      expect(restored.totalFare, equals(1340.0));
      expect(restored.paymentMethod, equals(PaymentMethod.wallet));
      expect(restored.isPaid, isTrue);
      expect(restored.driverEarnings, equals(1072.0));
      expect(restored.platformCommission, equals(268.0));
    });

    test('copyWith properly overrides designated attributes', () {
      const original = PricingDetails(
        baseFare: 500.0,
        distanceFare: 400.0,
        weightSurcharge: 0.0,
        totalFare: 900.0,
        isPaid: false,
      );

      final updated = original.copyWith(
        isPaid: true,
        totalFare: 950.0,
      );

      expect(updated.isPaid, isTrue);
      expect(updated.totalFare, equals(950.0));
      expect(updated.baseFare, equals(500.0)); // Unchanged
    });

    test('Equatable equality verification', () {
      const pricing1 = PricingDetails(
        baseFare: 500.0,
        distanceFare: 400.0,
        weightSurcharge: 0.0,
        totalFare: 900.0,
      );
      const pricing2 = PricingDetails(
        baseFare: 500.0,
        distanceFare: 400.0,
        weightSurcharge: 0.0,
        totalFare: 900.0,
      );
      const pricing3 = PricingDetails(
        baseFare: 750.0,
        distanceFare: 400.0,
        weightSurcharge: 0.0,
        totalFare: 1150.0,
      );

      expect(pricing1, equals(pricing2));
      expect(pricing1 == pricing3, isFalse);
    });
  });
}
