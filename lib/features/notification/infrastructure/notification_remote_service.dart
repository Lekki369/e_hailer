import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../../../core/domain/failures/app_failure.dart';
import '../../../../core/presentation/utils/fp_framework.dart';
import '../domain/entities/app_notification.dart';

class NotificationRemoteService {
  final FirebaseMessaging _messaging;
  final FirebaseFirestore _firestore;
  final _events = StreamController<AppNotification>.broadcast();
  StreamSubscription<String>? _registration;
  StreamSubscription<RemoteMessage>? _messages;
  Future<void> _queue = Future.value();
  String? _desiredUid;
  int _generation = 0;
  bool _disposed = false;
  NotificationRemoteService({
    FirebaseMessaging? messaging,
    FirebaseFirestore? firestore,
  }) : _messaging = messaging ?? FirebaseMessaging.instance,
       _firestore = firestore ?? FirebaseFirestore.instance;
  Stream<AppNotification> get foregroundNotifications => _events.stream;

  Future<Either<AppFailure, Unit>> syncSession(String? uid) async {
    if (_desiredUid == uid || _disposed) return right(unit);
    _desiredUid = uid;
    final generation = ++_generation;
    final previous = _queue;
    final done = Completer<void>();
    _queue = done.future;
    await previous;
    try {
      await _registration?.cancel();
      await _messages?.cancel();
      _registration = null;
      _messages = null;
      if (_disposed || generation != _generation) return right(unit);
      if (uid == null) {
        await _messaging.unregister();
        return right(unit);
      }
      final settings = await _messaging.requestPermission();
      if (_disposed || generation != _generation) return right(unit);
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        return left(
          const ServerFailure(
            message:
                'Notifications are disabled. You can enable them in Settings.',
          ),
        );
      }
      _registration = _messaging.onRegistered.listen((registrationId) async {
        if (_disposed || generation != _generation) return;
        try {
          await _firestore.collection('users').doc(uid).update({
            'fcmRegistrationId': registrationId,
            'fcmTokenUpdatedAt': DateTime.now().toUtc().toIso8601String(),
          });
        } catch (_) {
          /* Registration may race a sign-out. No sensitive logs. */
        }
      }, onError: (_) {});
      _messages = FirebaseMessaging.onMessage.listen((message) {
        if (_disposed || generation != _generation || _events.isClosed) return;
        final notification = message.notification;
        if (notification == null) return;
        _events.add(
          AppNotification(
            id:
                message.messageId ??
                DateTime.now().microsecondsSinceEpoch.toString(),
            title: notification.title ?? 'Delivery update',
            body: notification.body ?? '',
            type: NotificationType.fromString(message.data['type'] as String?),
            data: message.data,
            receivedAt: DateTime.now(),
          ),
        );
      }, onError: (_) {});
      await _messaging.register();
      return right(unit);
    } catch (_) {
      if (generation == _generation) _desiredUid = null;
      return left(
        const ServerFailure(
          message:
              'Notifications are temporarily unavailable. Delivery progress remains available in the app.',
        ),
      );
    } finally {
      done.complete();
    }
  }

  void dispose() {
    _disposed = true;
    _generation++;
    unawaited(_registration?.cancel());
    unawaited(_messages?.cancel());
    unawaited(_events.close());
  }
}
