import 'package:equatable/equatable.dart';

import '../value_objects/dispute_category.dart';
import '../value_objects/dispute_status.dart';

/// Represents a customer damage/incident claim or a driver failed-delivery dispute
class DeliveryDispute extends Equatable {
  final String id;
  final String orderId;
  final String trackingNumber;
  final String claimantId;
  final String claimantName;
  final String claimantRole; // 'customer' or 'driver'
  final String claimantPhone;
  final DisputeCategory category;
  final String description;
  final String? evidenceNotes;
  final DisputeStatus status;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final String? resolvedBy;
  final String? resolutionNotes;
  final double? refundAmount;
  final String? returnTrackingNumber;

  const DeliveryDispute({
    required this.id,
    required this.orderId,
    required this.trackingNumber,
    required this.claimantId,
    required this.claimantName,
    required this.claimantRole,
    required this.claimantPhone,
    required this.category,
    required this.description,
    this.evidenceNotes,
    this.status = DisputeStatus.open,
    required this.createdAt,
    this.resolvedAt,
    this.resolvedBy,
    this.resolutionNotes,
    this.refundAmount,
    this.returnTrackingNumber,
  });

  DeliveryDispute copyWith({
    String? id,
    String? orderId,
    String? trackingNumber,
    String? claimantId,
    String? claimantName,
    String? claimantRole,
    String? claimantPhone,
    DisputeCategory? category,
    String? description,
    String? evidenceNotes,
    DisputeStatus? status,
    DateTime? createdAt,
    DateTime? resolvedAt,
    String? resolvedBy,
    String? resolutionNotes,
    double? refundAmount,
    String? returnTrackingNumber,
  }) {
    return DeliveryDispute(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      trackingNumber: trackingNumber ?? this.trackingNumber,
      claimantId: claimantId ?? this.claimantId,
      claimantName: claimantName ?? this.claimantName,
      claimantRole: claimantRole ?? this.claimantRole,
      claimantPhone: claimantPhone ?? this.claimantPhone,
      category: category ?? this.category,
      description: description ?? this.description,
      evidenceNotes: evidenceNotes ?? this.evidenceNotes,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      resolvedBy: resolvedBy ?? this.resolvedBy,
      resolutionNotes: resolutionNotes ?? this.resolutionNotes,
      refundAmount: refundAmount ?? this.refundAmount,
      returnTrackingNumber: returnTrackingNumber ?? this.returnTrackingNumber,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'orderId': orderId,
      'trackingNumber': trackingNumber,
      'claimantId': claimantId,
      'claimantName': claimantName,
      'claimantRole': claimantRole,
      'claimantPhone': claimantPhone,
      'category': category.name,
      'description': description,
      'evidenceNotes': evidenceNotes,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
      'resolvedAt': resolvedAt?.toIso8601String(),
      'resolvedBy': resolvedBy,
      'resolutionNotes': resolutionNotes,
      'refundAmount': refundAmount,
      'returnTrackingNumber': returnTrackingNumber,
    };
  }

  factory DeliveryDispute.fromMap(Map<String, dynamic> map, String docId) {
    return DeliveryDispute(
      id: docId,
      orderId: map['orderId'] as String? ?? '',
      trackingNumber: map['trackingNumber'] as String? ?? '',
      claimantId: map['claimantId'] as String? ?? '',
      claimantName: map['claimantName'] as String? ?? 'User',
      claimantRole: map['claimantRole'] as String? ?? 'customer',
      claimantPhone: map['claimantPhone'] as String? ?? '',
      category: DisputeCategory.fromString(map['category'] as String?),
      description: map['description'] as String? ?? '',
      evidenceNotes: map['evidenceNotes'] as String?,
      status: DisputeStatus.fromString(map['status'] as String?),
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      resolvedAt: map['resolvedAt'] != null
          ? DateTime.tryParse(map['resolvedAt'].toString())
          : null,
      resolvedBy: map['resolvedBy'] as String?,
      resolutionNotes: map['resolutionNotes'] as String?,
      refundAmount: (map['refundAmount'] as num?)?.toDouble(),
      returnTrackingNumber: map['returnTrackingNumber'] as String?,
    );
  }

  @override
  List<Object?> get props => [
        id,
        orderId,
        trackingNumber,
        claimantId,
        claimantName,
        claimantRole,
        claimantPhone,
        category,
        description,
        evidenceNotes,
        status,
        createdAt,
        resolvedAt,
        resolvedBy,
        resolutionNotes,
        refundAmount,
        returnTrackingNumber,
      ];
}
