import 'package:equatable/equatable.dart';

import '../value_objects/delivery_status.dart';
import '../value_objects/delivery_type.dart';
import 'location_point.dart';
import 'parcel_details.dart';
import 'pricing_details.dart';

class DeliveryOrder extends Equatable {
  final String id;
  final String trackingNumber;
  final DeliveryType type;
  final VehicleType vehicleType;
  final DeliveryStatus status;
  final String customerId;
  final String customerName;
  final String customerPhone;
  final String? driverId;
  final String? driverName;
  final String? driverPhone;
  final double? driverLatitude;
  final double? driverLongitude;
  final LocationPoint pickupLocation;
  final LocationPoint dropoffLocation;
  final ParcelDetails parcel;
  final PricingDetails pricing;
  final double distanceKm;
  final int? estimatedDurationMinutes;
  final DateTime createdAt;
  final DateTime? scheduledAt;
  final DateTime? pickedUpAt;
  final DateTime? deliveredAt;
  final String? proofOfDeliverySignatureUrl;
  final String? proofOfDeliveryPhotoUrl;
  final String? cancellationReason;
  final String? cancelledByRole;
  final DateTime? cancelledAt;
  final double? customerRating;
  final String? customerReview;
  final String? recipientSecurityOtp;

  /// Whether the order has exceeded SLA dispatch or transit thresholds.
  bool get isDelayed {
    if (status == DeliveryStatus.delivered ||
        status == DeliveryStatus.cancelled ||
        status == DeliveryStatus.returnedToHub) {
      return false;
    }
    final now = DateTime.now();
    // 1. Unassigned order pending > 15 minutes
    if ((status == DeliveryStatus.created ||
            status == DeliveryStatus.searchingDriver) &&
        now.difference(createdAt).inMinutes > 15) {
      return true;
    }
    // 2. Active transit exceeding estimated duration + 15 min buffer
    if ((status == DeliveryStatus.inTransit ||
            status == DeliveryStatus.pickedUp ||
            status == DeliveryStatus.assigned) &&
        estimatedDurationMinutes != null) {
      final baseTime = pickedUpAt ?? createdAt;
      final expectedMinutes = estimatedDurationMinutes! + 15;
      if (now.difference(baseTime).inMinutes > expectedMinutes) {
        return true;
      }
    }
    return false;
  }

  /// Composite priority score for dispatch queue sorting (higher = more urgent).
  int get priorityScore {
    int score = 0;
    if (isDelayed) score += 1000;
    if (type == DeliveryType.express) score += 200;
    if (parcel.isFragile) score += 100;
    // Add age weight: 10 points for each 5 minutes waiting
    final ageMinutes = DateTime.now().difference(createdAt).inMinutes;
    score += (ageMinutes ~/ 5) * 10;
    return score;
  }

  /// Extracted primary zone or area from pickup address for regional clustering.
  String get pickupZone {
    final parts = pickupLocation.address.split(',');
    if (parts.length >= 2) {
      return parts[parts.length - 2].trim();
    }
    return pickupLocation.address.split(' ').first;
  }

  const DeliveryOrder({
    required this.id,
    required this.trackingNumber,
    required this.type,
    this.vehicleType = VehicleType.bike,
    required this.status,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    this.driverId,
    this.driverName,
    this.driverPhone,
    this.driverLatitude,
    this.driverLongitude,
    required this.pickupLocation,
    required this.dropoffLocation,
    required this.parcel,
    required this.pricing,
    required this.distanceKm,
    this.estimatedDurationMinutes,
    required this.createdAt,
    this.scheduledAt,
    this.pickedUpAt,
    this.deliveredAt,
    this.proofOfDeliverySignatureUrl,
    this.proofOfDeliveryPhotoUrl,
    this.cancellationReason,
    this.cancelledByRole,
    this.cancelledAt,
    this.customerRating,
    this.customerReview,
    this.recipientSecurityOtp,
  });

  DeliveryOrder copyWith({
    String? id,
    String? trackingNumber,
    DeliveryType? type,
    VehicleType? vehicleType,
    DeliveryStatus? status,
    String? customerId,
    String? customerName,
    String? customerPhone,
    String? driverId,
    String? driverName,
    String? driverPhone,
    double? driverLatitude,
    double? driverLongitude,
    LocationPoint? pickupLocation,
    LocationPoint? dropoffLocation,
    ParcelDetails? parcel,
    PricingDetails? pricing,
    double? distanceKm,
    int? estimatedDurationMinutes,
    DateTime? createdAt,
    DateTime? scheduledAt,
    DateTime? pickedUpAt,
    DateTime? deliveredAt,
    String? proofOfDeliverySignatureUrl,
    String? proofOfDeliveryPhotoUrl,
    String? cancellationReason,
    String? cancelledByRole,
    DateTime? cancelledAt,
    double? customerRating,
    String? customerReview,
    String? recipientSecurityOtp,
  }) {
    return DeliveryOrder(
      id: id ?? this.id,
      trackingNumber: trackingNumber ?? this.trackingNumber,
      type: type ?? this.type,
      vehicleType: vehicleType ?? this.vehicleType,
      status: status ?? this.status,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      driverId: driverId ?? this.driverId,
      driverName: driverName ?? this.driverName,
      driverPhone: driverPhone ?? this.driverPhone,
      driverLatitude: driverLatitude ?? this.driverLatitude,
      driverLongitude: driverLongitude ?? this.driverLongitude,
      pickupLocation: pickupLocation ?? this.pickupLocation,
      dropoffLocation: dropoffLocation ?? this.dropoffLocation,
      parcel: parcel ?? this.parcel,
      pricing: pricing ?? this.pricing,
      distanceKm: distanceKm ?? this.distanceKm,
      estimatedDurationMinutes:
          estimatedDurationMinutes ?? this.estimatedDurationMinutes,
      createdAt: createdAt ?? this.createdAt,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      pickedUpAt: pickedUpAt ?? this.pickedUpAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      proofOfDeliverySignatureUrl:
          proofOfDeliverySignatureUrl ?? this.proofOfDeliverySignatureUrl,
      proofOfDeliveryPhotoUrl:
          proofOfDeliveryPhotoUrl ?? this.proofOfDeliveryPhotoUrl,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      cancelledByRole: cancelledByRole ?? this.cancelledByRole,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      customerRating: customerRating ?? this.customerRating,
      customerReview: customerReview ?? this.customerReview,
      recipientSecurityOtp: recipientSecurityOtp ?? this.recipientSecurityOtp,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'trackingNumber': trackingNumber,
      'type': type.name,
      'vehicleType': vehicleType.name,
      'status': status.name,
      'customerId': customerId,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'driverId': driverId,
      'driverName': driverName,
      'driverPhone': driverPhone,
      'driverLatitude': driverLatitude,
      'driverLongitude': driverLongitude,
      'pickupLocation': pickupLocation.toMap(),
      'dropoffLocation': dropoffLocation.toMap(),
      'parcel': parcel.toMap(),
      'pricing': pricing.toMap(),
      'distanceKm': distanceKm,
      'estimatedDurationMinutes': estimatedDurationMinutes,
      'createdAt': createdAt.toIso8601String(),
      'scheduledAt': scheduledAt?.toIso8601String(),
      'pickedUpAt': pickedUpAt?.toIso8601String(),
      'deliveredAt': deliveredAt?.toIso8601String(),
      'proofOfDeliverySignatureUrl': proofOfDeliverySignatureUrl,
      'proofOfDeliveryPhotoUrl': proofOfDeliveryPhotoUrl,
      'cancellationReason': cancellationReason,
      'cancelledByRole': cancelledByRole,
      'cancelledAt': cancelledAt?.toIso8601String(),
      'customerRating': customerRating,
      'customerReview': customerReview,
      'recipientSecurityOtp': recipientSecurityOtp,
    };
  }

  factory DeliveryOrder.fromMap(Map<String, dynamic> map, [String? docId]) {
    return DeliveryOrder(
      id: docId ?? map['id'] as String? ?? '',
      trackingNumber: map['trackingNumber'] as String? ?? '',
      type: DeliveryType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => DeliveryType.express,
      ),
      vehicleType: VehicleType.values.firstWhere(
        (e) => e.name == map['vehicleType'],
        orElse: () => VehicleType.bike,
      ),
      status: DeliveryStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => DeliveryStatus.created,
      ),
      customerId: map['customerId'] as String? ?? '',
      customerName: map['customerName'] as String? ?? '',
      customerPhone: map['customerPhone'] as String? ?? '',
      driverId: map['driverId'] as String?,
      driverName: map['driverName'] as String?,
      driverPhone: map['driverPhone'] as String?,
      driverLatitude: (map['driverLatitude'] as num?)?.toDouble(),
      driverLongitude: (map['driverLongitude'] as num?)?.toDouble(),
      pickupLocation: LocationPoint.fromMap(
        map['pickupLocation'] as Map<String, dynamic>? ?? {},
      ),
      dropoffLocation: LocationPoint.fromMap(
        map['dropoffLocation'] as Map<String, dynamic>? ?? {},
      ),
      parcel: ParcelDetails.fromMap(
        map['parcel'] as Map<String, dynamic>? ?? {},
      ),
      pricing: PricingDetails.fromMap(
        map['pricing'] as Map<String, dynamic>? ?? {},
      ),
      distanceKm: (map['distanceKm'] as num?)?.toDouble() ?? 0.0,
      estimatedDurationMinutes:
          (map['estimatedDurationMinutes'] as num?)?.toInt(),
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      scheduledAt: map['scheduledAt'] != null
          ? DateTime.tryParse(map['scheduledAt'].toString())
          : null,
      pickedUpAt: map['pickedUpAt'] != null
          ? DateTime.tryParse(map['pickedUpAt'].toString())
          : null,
      deliveredAt: map['deliveredAt'] != null
          ? DateTime.tryParse(map['deliveredAt'].toString())
          : null,
      proofOfDeliverySignatureUrl:
          map['proofOfDeliverySignatureUrl'] as String?,
      proofOfDeliveryPhotoUrl: map['proofOfDeliveryPhotoUrl'] as String?,
      cancellationReason: map['cancellationReason'] as String?,
      cancelledByRole: map['cancelledByRole'] as String?,
      cancelledAt: map['cancelledAt'] != null
          ? DateTime.tryParse(map['cancelledAt'].toString())
          : null,
      customerRating: (map['customerRating'] as num?)?.toDouble(),
      customerReview: map['customerReview'] as String?,
      recipientSecurityOtp: map['recipientSecurityOtp'] as String?,
    );
  }

  @override
  List<Object?> get props => [
        id,
        trackingNumber,
        type,
        vehicleType,
        status,
        customerId,
        driverId,
        driverLatitude,
        driverLongitude,
        distanceKm,
        pricing,
        createdAt,
        cancellationReason,
        customerRating,
        customerReview,
      ];
}
