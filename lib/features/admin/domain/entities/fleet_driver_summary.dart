import 'package:equatable/equatable.dart';

import '../../../delivery/domain/value_objects/delivery_type.dart';

/// Aggregated representation of a driver in the dispatch fleet roster.
class FleetDriverSummary extends Equatable {
  final String uid;
  final String fullName;
  final String phone;
  final String email;
  final VehicleType vehicleType;
  final String? vehiclePlateNumber;
  final String? vehicleModel;
  final bool isAvailable;
  final double rating;
  final String? currentOrderId;
  final double? lastKnownLatitude;
  final double? lastKnownLongitude;
  final DateTime? lastActiveAt;

  const FleetDriverSummary({
    required this.uid,
    required this.fullName,
    required this.phone,
    required this.email,
    this.vehicleType = VehicleType.bike,
    this.vehiclePlateNumber,
    this.vehicleModel,
    this.isAvailable = false,
    this.rating = 5.0,
    this.currentOrderId,
    this.lastKnownLatitude,
    this.lastKnownLongitude,
    this.lastActiveAt,
  });

  /// Factory constructor to deserialize from Firestore user map
  factory FleetDriverSummary.fromMap(Map<String, dynamic> map, String docId) {
    return FleetDriverSummary(
      uid: docId,
      fullName: map['fullName'] as String? ?? 'Fleet Driver',
      phone: map['phone'] as String? ?? '',
      email: map['email'] as String? ?? '',
      vehicleType: VehicleType.fromString(map['vehicleType'] as String?),
      vehiclePlateNumber: map['vehiclePlateNumber'] as String?,
      vehicleModel: map['vehicleModel'] as String?,
      isAvailable: map['isAvailable'] as bool? ?? false,
      rating: (map['rating'] as num?)?.toDouble() ?? 5.0,
      currentOrderId: map['currentOrderId'] as String?,
      lastKnownLatitude: (map['lastKnownLatitude'] as num?)?.toDouble(),
      lastKnownLongitude: (map['lastKnownLongitude'] as num?)?.toDouble(),
      lastActiveAt: map['lastActiveAt'] != null
          ? DateTime.tryParse(map['lastActiveAt'] as String)
          : null,
    );
  }

  /// Serialize to map for Firestore updates
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'fullName': fullName,
      'phone': phone,
      'email': email,
      'vehicleType': vehicleType.name,
      'vehiclePlateNumber': vehiclePlateNumber,
      'vehicleModel': vehicleModel,
      'isAvailable': isAvailable,
      'rating': rating,
      'currentOrderId': currentOrderId,
      'lastKnownLatitude': lastKnownLatitude,
      'lastKnownLongitude': lastKnownLongitude,
      'lastActiveAt': lastActiveAt?.toIso8601String(),
    };
  }

  FleetDriverSummary copyWith({
    String? uid,
    String? fullName,
    String? phone,
    String? email,
    VehicleType? vehicleType,
    String? vehiclePlateNumber,
    String? vehicleModel,
    bool? isAvailable,
    double? rating,
    String? currentOrderId,
    double? lastKnownLatitude,
    double? lastKnownLongitude,
    DateTime? lastActiveAt,
  }) {
    return FleetDriverSummary(
      uid: uid ?? this.uid,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      vehicleType: vehicleType ?? this.vehicleType,
      vehiclePlateNumber: vehiclePlateNumber ?? this.vehiclePlateNumber,
      vehicleModel: vehicleModel ?? this.vehicleModel,
      isAvailable: isAvailable ?? this.isAvailable,
      rating: rating ?? this.rating,
      currentOrderId: currentOrderId ?? this.currentOrderId,
      lastKnownLatitude: lastKnownLatitude ?? this.lastKnownLatitude,
      lastKnownLongitude: lastKnownLongitude ?? this.lastKnownLongitude,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
    );
  }

  @override
  List<Object?> get props => [
        uid,
        fullName,
        phone,
        email,
        vehicleType,
        vehiclePlateNumber,
        vehicleModel,
        isAvailable,
        rating,
        currentOrderId,
        lastKnownLatitude,
        lastKnownLongitude,
        lastActiveAt,
      ];
}
