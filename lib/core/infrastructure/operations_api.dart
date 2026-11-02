import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:ehailer_client/ehailer_client.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:fpdart/fpdart.dart';
import 'package:serverpod_client/serverpod_client.dart';
import '../domain/failures/app_failure.dart';

typedef CommandTransport =
    Future<CommandReply> Function(
      String command,
      String payload,
      String requestId,
    );

/// The single boundary for trusted mutations. Pending request keys survive a
/// network retry and concurrent identical actions share the same Future.
class OperationsApi {
  static const configuredUrl = String.fromEnvironment('E_HAILER_API_URL');
  final CommandTransport? transport;
  final String Function() userId;
  final String baseUrl;
  final Duration timeout;
  Client? _client;
  final _pendingKeys = <String, String>{};
  final _inFlight =
      <String, Future<Either<AppFailure, Map<String, dynamic>>>>{};

  OperationsApi({
    this.transport,
    String Function()? userId,
    this.baseUrl = configuredUrl,
    this.timeout = const Duration(seconds: 25),
  }) : userId = userId ?? (() => FirebaseAuth.instance.currentUser?.uid ?? '');

  bool get isConfigured => transport != null || baseUrl.isNotEmpty;

  Future<Either<AppFailure, Map<String, dynamic>>> execute(
    String command,
    Map<String, dynamic> data,
  ) {
    if (!isConfigured) {
      return Future.value(
        left(
          const ServerFailure(
            message:
                'This service is not available yet. Please try again later.',
          ),
        ),
      );
    }
    final uid = userId();
    if (uid.isEmpty) {
      return Future.value(
        left(const AuthFailure(message: 'Please sign in to continue.')),
      );
    }
    final payload = jsonEncode(data);
    final fingerprint = sha256
        .convert(utf8.encode('$uid:$command:$payload'))
        .toString();
    return _inFlight.putIfAbsent(
      fingerprint,
      () => _send(command, payload, fingerprint).whenComplete(() {
        _inFlight.remove(fingerprint);
      }),
    );
  }

  Future<Either<AppFailure, Map<String, dynamic>>> _send(
    String command,
    String payload,
    String fingerprint,
  ) async {
    final key = _pendingKeys.putIfAbsent(fingerprint, () => const Uuid().v4());
    try {
      var caller = transport;
      if (caller == null) {
        final uri = Uri.tryParse(baseUrl);
        final local =
            uri != null &&
            {'localhost', '127.0.0.1', '10.0.2.2'}.contains(uri.host);
        if (uri == null ||
            uri.host.isEmpty ||
            uri.userInfo.isNotEmpty ||
            uri.hasQuery ||
            uri.hasFragment ||
            (uri.scheme != 'https' &&
                !(kDebugMode && local && uri.scheme == 'http'))) {
          return left(
            const ServerFailure(
              message: 'The service connection is not configured correctly.',
            ),
          );
        }
        _client ??= Client(
          baseUrl.endsWith('/') ? baseUrl : '$baseUrl/',
          connectionTimeout: timeout,
        )..authKeyProvider = _FirebaseAuthKeyProvider();
        caller = _client!.operations.execute;
      }
      final reply = await caller(command, payload, key).timeout(timeout);
      if (reply.errorCode != null) {
        if (reply.errorCode != 'unavailable') _pendingKeys.remove(fingerprint);
        return left(_failure(reply));
      }
      final decoded = jsonDecode(reply.dataJson);
      if (decoded is! Map<String, dynamic>) {
        return left(
          const ServerFailure(
            message: 'The service returned an unexpected response.',
          ),
        );
      }
      _pendingKeys.remove(fingerprint);
      return right(decoded);
    } on TimeoutException {
      return left(
        const NetworkFailure(
          message:
              'This is taking longer than expected. Retry to check the same request safely.',
        ),
      );
    } catch (_) {
      return left(
        const NetworkFailure(
          message:
              'Could not reach the service. Check your connection and retry.',
        ),
      );
    }
  }

  AppFailure _failure(CommandReply reply) {
    final message = reply.errorMessage ?? 'We could not complete this action.';
    return switch (reply.errorCode) {
      'unauthenticated' => AuthFailure(message: message),
      'permission-denied' => UnauthorizedActionFailure(message: message),
      'invalid-pin' || 'pin-locked' => InvalidOtpFailure(message: message),
      'not-found' => OrderNotFoundFailure(message: message),
      _ => ServerFailure(message: message),
    };
  }

  void dispose() {
    _client?.close();
    _pendingKeys.clear();
  }
}

class _FirebaseAuthKeyProvider implements ClientAuthKeyProvider {
  @override
  Future<String?> get authHeaderValue async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    return token == null ? null : wrapAsBearerAuthHeaderValue(token);
  }
}
