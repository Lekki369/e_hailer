import 'package:equatable/equatable.dart';
import '../value_objects/delivery_status.dart';

class PublicDeliveryTracking extends Equatable {
  final String trackingNumber;
  final DeliveryStatus status;
  final int estimatedDurationMinutes;
  final DateTime updatedAt;
  final List<PublicTrackingEvent> timeline;
  const PublicDeliveryTracking({
    required this.trackingNumber,
    required this.status,
    required this.estimatedDurationMinutes,
    required this.updatedAt,
    required this.timeline,
  });
  factory PublicDeliveryTracking.fromMap(Map<String, dynamic> map) =>
      PublicDeliveryTracking(
        trackingNumber: map['trackingNumber'] as String,
        status: DeliveryStatus.fromString(map['status'] as String?),
        estimatedDurationMinutes: (map['estimatedDurationMinutes'] as num? ?? 0)
            .toInt(),
        updatedAt: DateTime.parse(map['updatedAt'] as String),
        timeline: List.unmodifiable(
          (map['timeline'] as List? ?? []).map(
            (event) => PublicTrackingEvent.fromMap(
              Map<String, dynamic>.from(event as Map),
            ),
          ),
        ),
      );
  Map<String, dynamic> toMap() => {
    'trackingNumber': trackingNumber,
    'status': status.name,
    'estimatedDurationMinutes': estimatedDurationMinutes,
    'updatedAt': updatedAt.toIso8601String(),
    'timeline': timeline.map((e) => e.toMap()).toList(),
  };
  @override
  List<Object?> get props => [
    trackingNumber,
    status,
    estimatedDurationMinutes,
    updatedAt,
    timeline,
  ];
}

class PublicTrackingEvent extends Equatable {
  final DeliveryStatus status;
  final DateTime timestamp;
  const PublicTrackingEvent(this.status, this.timestamp);
  factory PublicTrackingEvent.fromMap(Map<String, dynamic> map) =>
      PublicTrackingEvent(
        DeliveryStatus.fromString(map['status'] as String?),
        DateTime.parse(map['timestamp'] as String),
      );
  Map<String, dynamic> toMap() => {
    'status': status.name,
    'timestamp': timestamp.toIso8601String(),
  };
  @override
  List<Object?> get props => [status, timestamp];
}
