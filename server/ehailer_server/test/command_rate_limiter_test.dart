import 'dart:io';
import 'package:firebase_admin_sdk/firebase_admin_sdk.dart';
import 'package:ehailer_server/src/core/domain/command_rate_limiter.dart';
import 'package:ehailer_server/src/core/domain/command_store.dart';
import 'package:ehailer_server/src/core/domain/operation_failure.dart';
import 'package:ehailer_server/src/core/infrastructure/firestore_command_store.dart';
import 'package:test/test.dart';
import 'support/memory_command_store.dart';

void main() {
  late CommandStore store;
  late DateTime now;
  late CommandRateLimiter limiter;
  var serial = 0;
  setUp(() {
    now = DateTime.utc(2026, 11, 2);
    final emulator = Platform.environment['FIRESTORE_EMULATOR_HOST'];
    if (emulator != null) {
      if (!emulator.startsWith('127.0.0.1:') &&
          !emulator.startsWith('localhost:')) {
        throw StateError('Tests require local emulators.');
      }
      final app = FirebaseApp.initializeApp(
        name: 'quota-${++serial}',
        options: AppOptions(projectId: 'demo-ehailer'),
      );
      store = FirestoreCommandStore(app.firestore());
      addTearDown(() => FirebaseApp.deleteApp(app));
    } else {
      store = MemoryCommandStore();
    }
    limiter = CommandRateLimiter(store, clock: () => now);
  });
  final denied = throwsA(
    isA<OperationFailure>().having((e) => e.code, 'code', 'resource-exhausted'),
  );

  test(
    'shared quota survives instances and refills without a window burst',
    () async {
      final uid = 'quota-user-${++serial}';
      for (var i = 0; i < 10; i++) {
        await limiter.consume(uid, 'quoteOrder');
      }
      final restarted = CommandRateLimiter(store, clock: () => now);
      await expectLater(restarted.consume(uid, 'quoteOrder'), denied);
      await restarted.consume('other-${++serial}', 'quoteOrder');
      now = now.add(const Duration(seconds: 6));
      await restarted.consume(uid, 'quoteOrder');
      await expectLater(limiter.consume(uid, 'quoteOrder'), denied);
    },
  );

  test('concurrent funding requests cannot exceed shared allowance', () async {
    final uid = 'funding-user-${++serial}';
    final results = await Future.wait(
      List.generate(12, (_) async {
        try {
          await limiter.consume(uid, 'initializeWalletTopUp');
          return true;
        } on OperationFailure catch (error) {
          expect(error.code, 'resource-exhausted');
          return false;
        }
      }),
    );
    expect(results.where((allowed) => allowed).length, 5);
  });

  test(
    'unknown commands share a bounded bucket and clock rollback grants no credit',
    () async {
      final uid = 'invalid-user-${++serial}';
      for (var i = 0; i < 30; i++) {
        await limiter.consume(uid, 'unknown-$i');
      }
      now = now.subtract(const Duration(minutes: 1));
      await expectLater(limiter.consume(uid, 'new-unknown'), denied);
      now = now.add(const Duration(minutes: 1));
      await expectLater(limiter.consume(uid, 'another-unknown'), denied);
      await expectLater(limiter.consume(uid, 'getWalletTopUp'), denied);
    },
  );
}
