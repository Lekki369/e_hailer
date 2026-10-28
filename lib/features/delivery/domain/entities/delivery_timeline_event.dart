import 'package:equatable/equatable.dart';

import '../value_objects/delivery_status.dart';

/// Immutable audit record representing an operational state transition or milestone event
class DeliveryTimelineEvent extends Equatable {
  final String id;
  final String orderId;
  final DeliveryStatus status;
  final String actorId;
  final String actorRole; // 'customer' | 'driver' | 'admin' | 'support' | 'system'
  final DateTime timestamp;
  final String? note;
  final double? latitude;
  final double? longitude;

  const DeliveryTimelineEvent({
    required this.id,
    required this.orderId,
    required this.status,
    required this.actorId,
    required this.actorRole,
    required this.timestamp,
    this.note,
    this.latitude,
    this.longitude,
  });

  DeliveryTimelineEvent copyWith({
    String? id,
    String? orderId,
    DeliveryStatus? status,
    String? actorId,
    String? actorRole,
    DateTime? timestamp,
    String? note,
    double? latitude,
    double? longitude,
  }) {
    return DeliveryTimelineEvent(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      status: status ?? this.status,
      actorId: actorId ?? this.actorId,
      actorRole: actorRole ?? this.actorRole,
      timestamp: timestamp ?? this.timestamp,
      note: note ?? this.note,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'orderId': orderId,
      'status': status.name,
      'actorId': actorId,
      'actorRole': actorRole,
      'timestamp': timestamp.toIso8601String(),
      'note': note,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  factory DeliveryTimelineEvent.fromMap(Map<String, dynamic> map, [String? docId]) {
    return DeliveryTimelineEvent(
      id: docId ?? map['id'] as String? ?? '',
      orderId: map['orderId'] as String? ?? '',
      status: DeliveryStatus.fromString(map['status'] as String?),
      actorId: map['actorId'] as String? ?? '',
      actorRole: map['actorRole'] as String? ?? 'system',
      timestamp: map['timestamp'] != null
          ? DateTime.tryParse(map['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
      note: map['note'] as String?,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
    );
  }

  @override
  List<Object?> get props => [
        id,
        orderId,
        status,
        actorId,
        actorRole,
        timestamp,
        note,
        latitude,
        longitude,
      ];
}
