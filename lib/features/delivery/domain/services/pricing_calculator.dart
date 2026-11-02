import '../entities/parcel_details.dart';
import '../entities/pricing_details.dart';
import '../value_objects/delivery_type.dart';

abstract class PricingCalculator {
  static const double baseRateBike = 500.0;
  static const double perKmRate = 120.0;
  static const double perKgRate = 80.0;
  static const double standardWeightAllowanceKg = 2.0;

  /// Calculates dynamic pricing combining on-demand hailing + volumetric parcel metrics
  static PricingDetails calculate({
    required double distanceKm,
    required ParcelDetails parcel,
    required VehicleType vehicleType,
    PaymentMethod paymentMethod = PaymentMethod.wallet,
    String currency = 'NGN',
  }) {
    // 1. Base fare multiplied by vehicle type
    final baseFare = baseRateBike * vehicleType.rateMultiplier;

    // 2. Distance fare
    final distanceFare = distanceKm * perKmRate;

    // 3. Volumetric & physical weight surcharge (from courierManagementSystem)
    final billableWeight = parcel.billableWeightKg;
    final chargeableExtraWeight = billableWeight > standardWeightAllowanceKg
        ? billableWeight - standardWeightAllowanceKg
        : 0.0;
    final weightSurcharge = chargeableExtraWeight * perKgRate;

    // 4. Fragile surcharge if applicable
    final fragileFee = parcel.isFragile ? 300.0 : 0.0;

    // 5. Total calculation
    final totalFare = baseFare + distanceFare + weightSurcharge + fragileFee;

    // 6. Split: 80% to driver, 20% platform commission
    final totalMinor = (totalFare / 10).round() * 1000;
    final commissionMinor = (totalMinor * 0.20).round();
    final driverEarnings = (totalMinor - commissionMinor) / 100;
    final platformCommission = commissionMinor / 100;

    return PricingDetails(
      baseFare: baseFare,
      distanceFare: distanceFare,
      weightSurcharge: weightSurcharge + fragileFee,
      totalFare: totalMinor / 100, // Round to nearest 10
      currency: currency,
      paymentMethod: paymentMethod,
      driverEarnings: driverEarnings,
      platformCommission: platformCommission,
    );
  }
}
