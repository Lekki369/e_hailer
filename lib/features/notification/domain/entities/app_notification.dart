import 'package:equatable/equatable.dart';

enum NotificationType {
  orderStatus('Delivery Status'),
  walletUpdate('Wallet & Payout'),
  general('Announcement');

  final String label;
  const NotificationType(this.label);

  static NotificationType fromString(String? value) {
    return NotificationType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => NotificationType.general,
    );
  }
}

class AppNotification extends Equatable {
  final String id;
  final String title;
  final String body;
  final NotificationType type;
  final Map<String, dynamic> data;
  final DateTime receivedAt;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.data = const {},
    required this.receivedAt,
  });

  @override
  List<Object?> get props => [
        id,
        title,
        body,
        type,
        data,
        receivedAt,
      ];
}
