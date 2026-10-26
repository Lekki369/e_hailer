import 'package:equatable/equatable.dart';
import '../value_objects/payout_status.dart';

/// Represents a driver's withdrawal request from their accrued digital wallet earnings.
class PayoutRequest extends Equatable {
  final String id;
  final String driverId;
  final String driverName;
  final String driverPhone;
  final double amount;
  final String bankName;
  final String accountNumber;
  final String accountName;
  final PayoutStatus status;
  final DateTime createdAt;
  final DateTime? processedAt;
  final String? processedBy;
  final String? rejectionReason;
  final String? transactionRef;

  const PayoutRequest({
    required this.id,
    required this.driverId,
    required this.driverName,
    required this.driverPhone,
    required this.amount,
    required this.bankName,
    required this.accountNumber,
    required this.accountName,
    this.status = PayoutStatus.pending,
    required this.createdAt,
    this.processedAt,
    this.processedBy,
    this.rejectionReason,
    this.transactionRef,
  });

  PayoutRequest copyWith({
    String? id,
    String? driverId,
    String? driverName,
    String? driverPhone,
    double? amount,
    String? bankName,
    String? accountNumber,
    String? accountName,
    PayoutStatus? status,
    DateTime? createdAt,
    DateTime? processedAt,
    String? processedBy,
    String? rejectionReason,
    String? transactionRef,
  }) {
    return PayoutRequest(
      id: id ?? this.id,
      driverId: driverId ?? this.driverId,
      driverName: driverName ?? this.driverName,
      driverPhone: driverPhone ?? this.driverPhone,
      amount: amount ?? this.amount,
      bankName: bankName ?? this.bankName,
      accountNumber: accountNumber ?? this.accountNumber,
      accountName: accountName ?? this.accountName,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      processedAt: processedAt ?? this.processedAt,
      processedBy: processedBy ?? this.processedBy,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      transactionRef: transactionRef ?? this.transactionRef,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'driverId': driverId,
      'driverName': driverName,
      'driverPhone': driverPhone,
      'amount': amount,
      'bankName': bankName,
      'accountNumber': accountNumber,
      'accountName': accountName,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
      'processedAt': processedAt?.toIso8601String(),
      'processedBy': processedBy,
      'rejectionReason': rejectionReason,
      'transactionRef': transactionRef,
    };
  }

  factory PayoutRequest.fromMap(Map<String, dynamic> map, String docId) {
    return PayoutRequest(
      id: docId,
      driverId: map['driverId'] as String? ?? '',
      driverName: map['driverName'] as String? ?? 'Fleet Driver',
      driverPhone: map['driverPhone'] as String? ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      bankName: map['bankName'] as String? ?? '',
      accountNumber: map['accountNumber'] as String? ?? '',
      accountName: map['accountName'] as String? ?? '',
      status: PayoutStatus.fromString(map['status'] as String?),
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      processedAt: map['processedAt'] != null
          ? DateTime.tryParse(map['processedAt'].toString())
          : null,
      processedBy: map['processedBy'] as String?,
      rejectionReason: map['rejectionReason'] as String?,
      transactionRef: map['transactionRef'] as String?,
    );
  }

  @override
  List<Object?> get props => [
        id,
        driverId,
        driverName,
        driverPhone,
        amount,
        bankName,
        accountNumber,
        accountName,
        status,
        createdAt,
        processedAt,
        processedBy,
        rejectionReason,
        transactionRef,
      ];
}
