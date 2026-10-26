import 'package:flutter_test/flutter_test.dart';
import 'package:e_hailer/features/delivery/domain/entities/parcel_details.dart';

void main() {
  group('ParcelDetails Entity', () {
    test('volumetricWeightKg returns 0.0 when any dimension is null', () {
      const parcelWithNoDimensions = ParcelDetails(
        category: PackageCategory.parcel,
        weightKg: 5.0,
      );
      expect(parcelWithNoDimensions.volumetricWeightKg, equals(0.0));

      const parcelWithMissingHeight = ParcelDetails(
        category: PackageCategory.parcel,
        weightKg: 5.0,
        lengthCm: 30.0,
        widthCm: 20.0,
      );
      expect(parcelWithMissingHeight.volumetricWeightKg, equals(0.0));
    });

    test('volumetricWeightKg calculates IATA formula: (L * W * H) / 5000', () {
      const parcel = ParcelDetails(
        category: PackageCategory.parcel,
        weightKg: 2.0,
        lengthCm: 50.0,
        widthCm: 40.0,
        heightCm: 25.0,
      );

      // (50 * 40 * 25) / 5000 = 50000 / 5000 = 10.0 kg
      expect(parcel.volumetricWeightKg, equals(10.0));
    });

    test('billableWeightKg selects max of physical vs volumetric weight', () {
      // Case 1: Physical (15kg) > Volumetric (10kg) -> Billable = 15kg
      const heavierPhysical = ParcelDetails(
        category: PackageCategory.heavy,
        weightKg: 15.0,
        lengthCm: 50.0,
        widthCm: 40.0,
        heightCm: 25.0, // vol = 10.0
      );
      expect(heavierPhysical.billableWeightKg, equals(15.0));

      // Case 2: Volumetric (10kg) > Physical (3kg) -> Billable = 10kg
      const bulkyLight = ParcelDetails(
        category: PackageCategory.parcel,
        weightKg: 3.0,
        lengthCm: 50.0,
        widthCm: 40.0,
        heightCm: 25.0, // vol = 10.0
      );
      expect(bulkyLight.billableWeightKg, equals(10.0));
    });

    test('PackageCategory.fromString maps case-insensitively and has fallback', () {
      expect(PackageCategory.fromString('document'), equals(PackageCategory.document));
      expect(PackageCategory.fromString('FOOD'), equals(PackageCategory.food));
      expect(PackageCategory.fromString('fragile'), equals(PackageCategory.fragile));
      expect(PackageCategory.fromString('heavy'), equals(PackageCategory.heavy));
      expect(PackageCategory.fromString('unknown_category'), equals(PackageCategory.parcel));
      expect(PackageCategory.fromString(null), equals(PackageCategory.parcel));
    });

    test('Serialization: toMap and fromMap produce identical entity', () {
      const original = ParcelDetails(
        category: PackageCategory.fragile,
        weightKg: 4.5,
        quantity: 3,
        lengthCm: 35.0,
        widthCm: 25.0,
        heightCm: 15.0,
        description: 'Delicate glassware set',
        isFragile: true,
      );

      final map = original.toMap();
      final restored = ParcelDetails.fromMap(map);

      expect(restored, equals(original));
      expect(restored.category, equals(PackageCategory.fragile));
      expect(restored.description, equals('Delicate glassware set'));
      expect(restored.isFragile, isTrue);
      expect(restored.volumetricWeightKg, equals((35.0 * 25.0 * 15.0) / 5000.0));
    });

    test('copyWith updates fields selectively', () {
      const original = ParcelDetails(
        category: PackageCategory.document,
        weightKg: 0.5,
        isFragile: false,
      );

      final updated = original.copyWith(
        category: PackageCategory.parcel,
        weightKg: 2.5,
        isFragile: true,
      );

      expect(updated.category, equals(PackageCategory.parcel));
      expect(updated.weightKg, equals(2.5));
      expect(updated.isFragile, isTrue);
      expect(updated.quantity, equals(1)); // Preserved
    });

    test('Equatable value equality check', () {
      const parcelA = ParcelDetails(
        category: PackageCategory.food,
        weightKg: 2.0,
      );
      const parcelB = ParcelDetails(
        category: PackageCategory.food,
        weightKg: 2.0,
      );
      const parcelC = ParcelDetails(
        category: PackageCategory.food,
        weightKg: 3.0,
      );

      expect(parcelA, equals(parcelB));
      expect(parcelA == parcelC, isFalse);
    });
  });
}
