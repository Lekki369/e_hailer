import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../domain/entities/app_notification.dart';
import '../../infrastructure/notification_remote_service.dart';

/// Provider for Notification Remote Service
final notificationRemoteServiceProvider =
    Provider<NotificationRemoteService>((ref) {
  final service = NotificationRemoteService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Stream provider for foreground in-app notifications
final foregroundNotificationStreamProvider =
    StreamProvider<AppNotification>((ref) {
  final service = ref.watch(notificationRemoteServiceProvider);
  return service.foregroundNotifications;
});
