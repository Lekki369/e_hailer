import 'package:flutter_test/flutter_test.dart';
import 'package:e_hailer/features/delivery/domain/entities/parcel_details.dart';
import 'package:e_hailer/features/delivery/domain/services/pricing_calculator.dart';
import 'package:e_hailer/features/delivery/domain/value_objects/delivery_type.dart';

void main() {
  group('PricingCalculator', () {
    const defaultParcel = ParcelDetails(
      category: PackageCategory.parcel,
      weightKg: 1.0,
      isFragile: false,
    );

    group('Vehicle Type Multipliers & Base Fares', () {
      test('Bike has base fare of ₦500 (1.0x)', () {
        final pricing = PricingCalculator.calculate(
          distanceKm: 0.0,
          parcel: defaultParcel,
          vehicleType: VehicleType.bike,
        );

        expect(pricing.baseFare, equals(500.0));
      });

      test('Car/Sedan has base fare of ₦750 (1.5x)', () {
        final pricing = PricingCalculator.calculate(
          distanceKm: 0.0,
          parcel: defaultParcel,
          vehicleType: VehicleType.car,
        );

        expect(pricing.baseFare, equals(750.0));
      });

      test('Van has base fare of ₦1,100 (2.2x)', () {
        final pricing = PricingCalculator.calculate(
          distanceKm: 0.0,
          parcel: defaultParcel,
          vehicleType: VehicleType.van,
        );

        expect(pricing.baseFare, equals(1100.0));
      });

      test('Heavy Truck has base fare of ₦1,750 (3.5x)', () {
        final pricing = PricingCalculator.calculate(
          distanceKm: 0.0,
          parcel: defaultParcel,
          vehicleType: VehicleType.truck,
        );

        expect(pricing.baseFare, equals(1750.0));
      });
    });

    group('Distance Fare Calculation (₦120/km)', () {
      test('0 km results in ₦0 distance fare', () {
        final pricing = PricingCalculator.calculate(
          distanceKm: 0.0,
          parcel: defaultParcel,
          vehicleType: VehicleType.bike,
        );

        expect(pricing.distanceFare, equals(0.0));
      });

      test('5.0 km results in ₦600 distance fare', () {
        final pricing = PricingCalculator.calculate(
          distanceKm: 5.0,
          parcel: defaultParcel,
          vehicleType: VehicleType.bike,
        );

        expect(pricing.distanceFare, equals(600.0));
      });

      test('12.5 km results in ₦1,500 distance fare', () {
        final pricing = PricingCalculator.calculate(
          distanceKm: 12.5,
          parcel: defaultParcel,
          vehicleType: VehicleType.bike,
        );

        expect(pricing.distanceFare, equals(1500.0));
      });
    });

    group('Weight & Volumetric Surcharges (₦80/kg above 2kg)', () {
      test('Standard package <= 2.0kg incurs ₦0 weight surcharge', () {
        const lightParcel = ParcelDetails(
          category: PackageCategory.parcel,
          weightKg: 1.5,
        );

        final pricing = PricingCalculator.calculate(
          distanceKm: 0.0,
          parcel: lightParcel,
          vehicleType: VehicleType.bike,
        );

        expect(pricing.weightSurcharge, equals(0.0));
      });

      test('Package exactly 2.0kg incurs ₦0 weight surcharge', () {
        const exactParcel = ParcelDetails(
          category: PackageCategory.parcel,
          weightKg: 2.0,
        );

        final pricing = PricingCalculator.calculate(
          distanceKm: 0.0,
          parcel: exactParcel,
          vehicleType: VehicleType.bike,
        );

        expect(pricing.weightSurcharge, equals(0.0));
      });

      test('Heavy physical parcel (5.0kg) incurs 3kg extra surcharge (₦240)', () {
        const heavyParcel = ParcelDetails(
          category: PackageCategory.parcel,
          weightKg: 5.0,
        );

        final pricing = PricingCalculator.calculate(
          distanceKm: 0.0,
          parcel: heavyParcel,
          vehicleType: VehicleType.bike,
        );

        // (5.0 - 2.0) * 80 = 240.0
        expect(pricing.weightSurcharge, equals(240.0));
      });

      test('IATA Volumetric weight calculation (L*W*H / 5000) when higher than physical', () {
        // 50cm * 40cm * 30cm / 5000 = 12.0kg volumetric weight
        // Physical weight = 1.0kg -> Billable weight = 12.0kg
        const bulkyParcel = ParcelDetails(
          category: PackageCategory.parcel,
          weightKg: 1.0,
          lengthCm: 50.0,
          widthCm: 40.0,
          heightCm: 30.0,
        );

        expect(bulkyParcel.volumetricWeightKg, equals(12.0));
        expect(bulkyParcel.billableWeightKg, equals(12.0));

        final pricing = PricingCalculator.calculate(
          distanceKm: 0.0,
          parcel: bulkyParcel,
          vehicleType: VehicleType.bike,
        );

        // (12.0 - 2.0) * 80 = 800.0
        expect(pricing.weightSurcharge, equals(800.0));
      });

      test('Physical weight takes precedence when higher than volumetric weight', () {
        // 20cm * 20cm * 10cm / 5000 = 0.8kg volumetric weight
        // Physical weight = 6.0kg -> Billable weight = 6.0kg
        const compactHeavyParcel = ParcelDetails(
          category: PackageCategory.parcel,
          weightKg: 6.0,
          lengthCm: 20.0,
          widthCm: 20.0,
          heightCm: 10.0,
        );

        expect(compactHeavyParcel.volumetricWeightKg, equals(0.8));
        expect(compactHeavyParcel.billableWeightKg, equals(6.0));

        final pricing = PricingCalculator.calculate(
          distanceKm: 0.0,
          parcel: compactHeavyParcel,
          vehicleType: VehicleType.bike,
        );

        // (6.0 - 2.0) * 80 = 320.0
        expect(pricing.weightSurcharge, equals(320.0));
      });
    });

    group('Fragile Item Handling Fee', () {
      test('Non-fragile parcel incurs ₦0 fragile fee', () {
        final pricing = PricingCalculator.calculate(
          distanceKm: 0.0,
          parcel: defaultParcel,
          vehicleType: VehicleType.bike,
        );

        expect(pricing.weightSurcharge, equals(0.0));
      });

      test('Fragile parcel incurs flat ₦300 fee in surcharge', () {
        const fragileParcel = ParcelDetails(
          category: PackageCategory.fragile,
          weightKg: 1.0,
          isFragile: true,
        );

        final pricing = PricingCalculator.calculate(
          distanceKm: 0.0,
          parcel: fragileParcel,
          vehicleType: VehicleType.bike,
        );

        // weightSurcharge includes 0 (for weight <= 2kg) + 300 (fragile fee)
        expect(pricing.weightSurcharge, equals(300.0));
        // Base 500 + Fragile 300 = 800
        expect(pricing.totalFare, equals(800.0));
      });

      test('Fragile parcel with excess weight combines both surcharges', () {
        const heavyFragileParcel = ParcelDetails(
          category: PackageCategory.fragile,
          weightKg: 4.0, // 2kg excess -> 2 * 80 = 160
          isFragile: true, // 300 fee
        );

        final pricing = PricingCalculator.calculate(
          distanceKm: 0.0,
          parcel: heavyFragileParcel,
          vehicleType: VehicleType.bike,
        );

        // 160 weight + 300 fragile = 460
        expect(pricing.weightSurcharge, equals(460.0));
        // Base 500 + 460 = 960
        expect(pricing.totalFare, equals(960.0));
      });
    });

    group('Revenue Split Integrity (80% Driver, 20% Platform)', () {
      test('Driver receives 80% and platform receives 20% of subtotal', () {
        final pricing = PricingCalculator.calculate(
          distanceKm: 10.0, // 10 * 120 = 1200
          parcel: defaultParcel, // Base bike = 500
          vehicleType: VehicleType.bike,
        );

        // Subtotal = 500 + 1200 = 1700
        expect(pricing.driverEarnings, equals(1700.0 * 0.80)); // 1360
        expect(pricing.platformCommission, equals(1700.0 * 0.20)); // 340
        expect(
          pricing.driverEarnings! + pricing.platformCommission!,
          equals(1700.0),
        );
      });
    });

    group('Nearest 10 Rounding Logic', () {
      test('Rounds total fare to nearest 10 NGN', () {
        // Bike base: 500
        // Distance: 3.3 km * 120 = 396
        // Raw total = 896 -> Rounds to 900
        final pricing = PricingCalculator.calculate(
          distanceKm: 3.3,
          parcel: defaultParcel,
          vehicleType: VehicleType.bike,
        );

        expect(pricing.totalFare, equals(900.0));
      });

      test('Rounds 894 down to 890 NGN', () {
        // Bike base: 500
        // Distance: 3.28 km * 120 = 393.6 -> rounds to 890
        final pricing = PricingCalculator.calculate(
          distanceKm: 3.28,
          parcel: defaultParcel,
          vehicleType: VehicleType.bike,
        );

        // Raw = 500 + 393.6 = 893.6 -> (893.6 / 10).round() * 10 = 89 * 10 = 890.0
        expect(pricing.totalFare, equals(890.0));
      });
    });
  });
}
