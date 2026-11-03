import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'command_store.dart';
import 'operation_failure.dart';

/// Shared, durable token buckets. A restart or another API instance cannot reset
/// a UID's quota. Denials commit the global bucket, including invalid requests.
class CommandRateLimiter {
  final CommandStore store;
  final DateTime Function() clock;
  CommandRateLimiter(this.store, {DateTime Function()? clock})
    : clock = clock ?? DateTime.now;

  Future<void> consume(String uid, String command) async {
    identifier(uid);
    final (group, capacity, seconds) = switch (command) {
      'quoteOrder' => ('quotes', 10, 60),
      'initializeWalletTopUp' => ('funding', 5, 600),
      'verifyWalletTopUp' => ('verification', 20, 60),
      'updateDriverLocation' => ('location', 90, 60),
      _ => ('actions', 30, 60),
    };
    final path = 'apiQuotas/${sha256.convert(utf8.encode(uid))}';
    final now = clock().toUtc().millisecondsSinceEpoch;
    final allowed = await store.transaction((tx) async {
      final data = await tx.get(path) ?? <String, dynamic>{};
      bool debit(String key, int cap, int period) {
        final old = data[key] as Map?;
        final last = (old?['at'] as num?)?.toInt() ?? now;
        final elapsed = (now - last).clamp(0, period * 1000);
        final tokens =
            ((old?['tokens'] as num?)?.toDouble() ?? cap) +
            elapsed * cap / (period * 1000);
        final available = tokens.clamp(0, cap).toDouble();
        data[key] = {
          'at': now < last ? last : now,
          'tokens': available >= 1 ? available - 1 : available,
        };
        return available >= 1;
      }

      final global = debit('all', 120, 60);
      final specific = global && debit(group, capacity, seconds);
      tx.set(path, data);
      return global && specific;
    });
    requireCondition(
      allowed,
      'Too many requests. Please wait a moment before trying again.',
      'resource-exhausted',
    );
  }
}
