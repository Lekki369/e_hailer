import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/domain/failures/app_failure.dart';
import '../../../../core/presentation/utils/fp_framework.dart';
import '../domain/entities/app_notification.dart';

class NotificationRemoteService {
  final FirebaseMessaging _messaging;
  final FirebaseFirestore _firestore;
  final _foregroundNotificationController =
      StreamController<AppNotification>.broadcast();

  NotificationRemoteService({
    FirebaseMessaging? messaging,
    FirebaseFirestore? firestore,
  })  : _messaging = messaging ?? FirebaseMessaging.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  Stream<AppNotification> get foregroundNotifications =>
      _foregroundNotificationController.stream;

  /// Initialize notifications, request permissions, and register FCM Token to user document
  Future<Either<AppFailure, String?>> initialize({required String uid}) async {
    try {
      // 1. Request notification permissions
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        return left(const ServerFailure(
          message: 'Notification permission was denied by the user.',
        ));
      }

      // 2. Retrieve FCM Token
      String? token;
      try {
        token = await _messaging.getToken();
        if (token != null) {
          await _saveTokenToFirestore(uid, token);
        }
      } catch (e) {
        debugPrint('FCM getToken note (e.g. APNs on simulator or web): $e');
      }

      // 3. Listen to token refresh
      _messaging.onTokenRefresh.listen((newToken) {
        _saveTokenToFirestore(uid, newToken);
      });

      // 4. Foreground message listener
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        final notification = message.notification;
        if (notification != null) {
          final appNotif = AppNotification(
            id: message.messageId ??
                DateTime.now().millisecondsSinceEpoch.toString(),
            title: notification.title ?? 'e-Hailer Alert',
            body: notification.body ?? '',
            type: NotificationType.fromString(message.data['type'] as String?),
            data: message.data,
            receivedAt: DateTime.now(),
          );
          _foregroundNotificationController.add(appNotif);
        }
      });

      return right(token);
    } catch (e) {
      return left(
          ServerFailure(message: 'Failed to initialize notifications: $e'));
    }
  }

  Future<void> _saveTokenToFirestore(String uid, String token) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'fcmToken': token,
        'fcmTokenUpdatedAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error updating FCM token in Firestore: $e');
    }
  }

  void dispose() {
    _foregroundNotificationController.close();
  }
}
