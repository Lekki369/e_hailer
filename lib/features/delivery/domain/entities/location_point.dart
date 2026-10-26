import 'package:equatable/equatable.dart';

class LocationPoint extends Equatable {
  final double latitude;
  final double longitude;
  final String address;
  final String contactName;
  final String contactPhone;
  final String? landmarkOrNote;

  const LocationPoint({
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.contactName,
    required this.contactPhone,
    this.landmarkOrNote,
  });

  LocationPoint copyWith({
    double? latitude,
    double? longitude,
    String? address,
    String? contactName,
    String? contactPhone,
    String? landmarkOrNote,
  }) {
    return LocationPoint(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      contactName: contactName ?? this.contactName,
      contactPhone: contactPhone ?? this.contactPhone,
      landmarkOrNote: landmarkOrNote ?? this.landmarkOrNote,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'contactName': contactName,
      'contactPhone': contactPhone,
      'landmarkOrNote': landmarkOrNote,
    };
  }

  factory LocationPoint.fromMap(Map<String, dynamic> map) {
    return LocationPoint(
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      address: map['address'] as String? ?? '',
      contactName: map['contactName'] as String? ?? '',
      contactPhone: map['contactPhone'] as String? ?? '',
      landmarkOrNote: map['landmarkOrNote'] as String?,
    );
  }

  @override
  List<Object?> get props => [
        latitude,
        longitude,
        address,
        contactName,
        contactPhone,
        landmarkOrNote,
      ];
}
