import 'package:equatable/equatable.dart';

enum PaymentMethod {
  wallet('In-App Wallet'),
  card('Credit/Debit Card (Paystack/Stripe)'),
  cashOnDelivery('Cash on Delivery');

  final String label;
  const PaymentMethod(this.label);

  static PaymentMethod fromString(String? value) {
    return PaymentMethod.values.firstWhere(
      (e) => e.name.toLowerCase() == (value ?? '').toLowerCase(),
      orElse: () => PaymentMethod.wallet,
    );
  }
}

class PricingDetails extends Equatable {
  final double baseFare;
  final double distanceFare;
  final double weightSurcharge;
  final double totalFare;
  final String currency;
  final PaymentMethod paymentMethod;
  final bool isPaid;
  final double? driverEarnings;
  final double? platformCommission;

  const PricingDetails({
    required this.baseFare,
    required this.distanceFare,
    required this.weightSurcharge,
    required this.totalFare,
    this.currency = 'NGN',
    this.paymentMethod = PaymentMethod.wallet,
    this.isPaid = false,
    this.driverEarnings,
    this.platformCommission,
  });

  PricingDetails copyWith({
    double? baseFare,
    double? distanceFare,
    double? weightSurcharge,
    double? totalFare,
    String? currency,
    PaymentMethod? paymentMethod,
    bool? isPaid,
    double? driverEarnings,
    double? platformCommission,
  }) {
    return PricingDetails(
      baseFare: baseFare ?? this.baseFare,
      distanceFare: distanceFare ?? this.distanceFare,
      weightSurcharge: weightSurcharge ?? this.weightSurcharge,
      totalFare: totalFare ?? this.totalFare,
      currency: currency ?? this.currency,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      isPaid: isPaid ?? this.isPaid,
      driverEarnings: driverEarnings ?? this.driverEarnings,
      platformCommission: platformCommission ?? this.platformCommission,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'baseFare': baseFare,
      'distanceFare': distanceFare,
      'weightSurcharge': weightSurcharge,
      'totalFare': totalFare,
      'currency': currency,
      'paymentMethod': paymentMethod.name,
      'isPaid': isPaid,
      'driverEarnings': driverEarnings,
      'platformCommission': platformCommission,
    };
  }

  factory PricingDetails.fromMap(Map<String, dynamic> map) {
    return PricingDetails(
      baseFare: (map['baseFare'] as num?)?.toDouble() ?? 0.0,
      distanceFare: (map['distanceFare'] as num?)?.toDouble() ?? 0.0,
      weightSurcharge: (map['weightSurcharge'] as num?)?.toDouble() ?? 0.0,
      totalFare: (map['totalFare'] as num?)?.toDouble() ?? 0.0,
      currency: map['currency'] as String? ?? 'NGN',
      paymentMethod: PaymentMethod.fromString(map['paymentMethod'] as String?),
      isPaid: map['isPaid'] as bool? ?? false,
      driverEarnings: (map['driverEarnings'] as num?)?.toDouble(),
      platformCommission: (map['platformCommission'] as num?)?.toDouble(),
    );
  }

  @override
  List<Object?> get props => [
        baseFare,
        distanceFare,
        weightSurcharge,
        totalFare,
        currency,
        paymentMethod,
        isPaid,
        driverEarnings,
        platformCommission,
      ];
}
