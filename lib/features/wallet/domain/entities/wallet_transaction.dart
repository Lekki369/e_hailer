import 'package:equatable/equatable.dart';
import '../value_objects/transaction_type.dart';

class WalletTransaction extends Equatable {
  final String id;
  final String userId;
  final double amount;
  final TransactionType type;
  final String title;
  final String description;
  final String? referenceId;
  final DateTime createdAt;

  const WalletTransaction({
    required this.id,
    required this.userId,
    required this.amount,
    required this.type,
    required this.title,
    required this.description,
    this.referenceId,
    required this.createdAt,
  });

  WalletTransaction copyWith({
    String? id,
    String? userId,
    double? amount,
    TransactionType? type,
    String? title,
    String? description,
    String? referenceId,
    DateTime? createdAt,
  }) {
    return WalletTransaction(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      title: title ?? this.title,
      description: description ?? this.description,
      referenceId: referenceId ?? this.referenceId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'amount': amount,
      'type': type.name,
      'title': title,
      'description': description,
      'referenceId': referenceId,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory WalletTransaction.fromMap(Map<String, dynamic> map, String id) {
    return WalletTransaction(
      id: id,
      userId: map['userId'] as String? ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      type: TransactionType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => TransactionType.tripPayment,
      ),
      title: map['title'] as String? ?? 'Transaction',
      description: map['description'] as String? ?? '',
      referenceId: map['referenceId'] as String?,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        amount,
        type,
        title,
        description,
        referenceId,
        createdAt,
      ];
}
