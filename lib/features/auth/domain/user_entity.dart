import 'package:equatable/equatable.dart';
import '../../delivery/domain/value_objects/delivery_type.dart';

enum UserRole {
  customer('Customer'),
  driver('Rider / Driver'),
  admin('Hub Dispatcher / Admin');

  final String label;
  const UserRole(this.label);

  static UserRole fromString(String? value) {
    return UserRole.values.firstWhere(
      (e) => e.name.toLowerCase() == (value ?? '').toLowerCase(),
      orElse: () => UserRole.customer,
    );
  }
}

class UserEntity extends Equatable {
  final String uid;
  final UserRole role;
  final String fullName;
  final String email;
  final String phone;
  final String? avatarUrl;
  final double walletBalance;
  final double rating;
  final bool isAvailable;
  final VehicleType? vehicleType;
  final String? vehiclePlateNumber;
  final String? vehicleModel;
  final DateTime createdAt;

  const UserEntity({
    required this.uid,
    required this.role,
    required this.fullName,
    required this.email,
    required this.phone,
    this.avatarUrl,
    this.walletBalance = 0.0,
    this.rating = 5.0,
    this.isAvailable = false,
    this.vehicleType,
    this.vehiclePlateNumber,
    this.vehicleModel,
    required this.createdAt,
  });

  UserEntity copyWith({
    String? uid,
    UserRole? role,
    String? fullName,
    String? email,
    String? phone,
    String? avatarUrl,
    double? walletBalance,
    double? rating,
    bool? isAvailable,
    VehicleType? vehicleType,
    String? vehiclePlateNumber,
    String? vehicleModel,
    DateTime? createdAt,
  }) {
    return UserEntity(
      uid: uid ?? this.uid,
      role: role ?? this.role,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      walletBalance: walletBalance ?? this.walletBalance,
      rating: rating ?? this.rating,
      isAvailable: isAvailable ?? this.isAvailable,
      vehicleType: vehicleType ?? this.vehicleType,
      vehiclePlateNumber: vehiclePlateNumber ?? this.vehiclePlateNumber,
      vehicleModel: vehicleModel ?? this.vehicleModel,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'role': role.name,
      'fullName': fullName,
      'email': email,
      'phone': phone,
      'avatarUrl': avatarUrl,
      'walletBalance': walletBalance,
      'rating': rating,
      'isAvailable': isAvailable,
      'vehicleType': vehicleType?.name,
      'vehiclePlateNumber': vehiclePlateNumber,
      'vehicleModel': vehicleModel,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory UserEntity.fromMap(Map<String, dynamic> map, [String? docId]) {
    return UserEntity(
      uid: docId ?? map['uid'] as String? ?? '',
      role: UserRole.fromString(map['role'] as String?),
      fullName: map['fullName'] as String? ?? '',
      email: map['email'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      avatarUrl: map['avatarUrl'] as String?,
      walletBalance: (map['walletBalance'] as num?)?.toDouble() ?? 0.0,
      rating: (map['rating'] as num?)?.toDouble() ?? 5.0,
      isAvailable: map['isAvailable'] as bool? ?? false,
      vehicleType: map['vehicleType'] != null
          ? VehicleType.values.firstWhere(
              (e) => e.name == map['vehicleType'],
              orElse: () => VehicleType.bike,
            )
          : null,
      vehiclePlateNumber: map['vehiclePlateNumber'] as String?,
      vehicleModel: map['vehicleModel'] as String?,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [
        uid,
        role,
        fullName,
        email,
        phone,
        avatarUrl,
        walletBalance,
        rating,
        isAvailable,
        vehicleType,
        vehiclePlateNumber,
        vehicleModel,
        createdAt,
      ];
}
