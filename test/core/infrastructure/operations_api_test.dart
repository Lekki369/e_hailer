import 'dart:async';
import 'package:ehailer_client/ehailer_client.dart';
import 'package:e_hailer/core/infrastructure/operations_api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'credential-bearing or ambiguous API URLs fail before token access',
    () async {
      for (final url in [
        'https://user:password@example.test/',
        'https://example.test/?token=private',
        'https://example.test/#fragment',
        'http://remote.example.test/',
      ]) {
        final api = OperationsApi(baseUrl: url, userId: () => 'customer');
        final result = await api.execute('getWalletTopUp', {});
        expect(
          result.fold((failure) => failure.message, (_) => ''),
          'The service connection is not configured correctly.',
        );
        api.dispose();
      }
    },
  );
  test(
    'concurrent identical commands share one request and one server result',
    () async {
      var calls = 0;
      final reply = Completer<CommandReply>();
      final api = OperationsApi(
        userId: () => 'customer',
        transport: (_, _, _) {
          calls++;
          return reply.future;
        },
      );
      final a = api.execute('createOrder', {'quoteId': 'quote'});
      final b = api.execute('createOrder', {'quoteId': 'quote'});
      expect(calls, 1);
      reply.complete(CommandReply(dataJson: '{"id":"order"}'));
      expect((await a).getOrElse((_) => {})['id'], 'order');
      expect(await b, await a);
    },
  );
  test('a timed-out request retains its key for a safe retry', () async {
    final keys = <String>[];
    final api = OperationsApi(
      userId: () => 'customer',
      timeout: const Duration(milliseconds: 2),
      transport: (_, _, key) async {
        keys.add(key);
        if (keys.length == 1) return Completer<CommandReply>().future;
        return CommandReply(dataJson: '{"id":"order"}');
      },
    );
    expect(
      (await api.execute('createOrder', {'quoteId': 'quote'})).isLeft(),
      isTrue,
    );
    expect(
      (await api.execute('createOrder', {'quoteId': 'quote'})).isRight(),
      isTrue,
    );
    expect(keys[1], keys[0]);
    await api.execute('createOrder', {'quoteId': 'quote'});
    expect(keys[2], isNot(keys[1]));
  });
  test(
    'malformed success and retryable server errors retain the request key',
    () async {
      final keys = <String>[];
      final api = OperationsApi(
        userId: () => 'customer',
        transport: (_, _, key) async {
          keys.add(key);
          if (keys.length == 1) return CommandReply(dataJson: '[]');
          if (keys.length == 2) {
            return CommandReply(dataJson: '{}', errorCode: 'unavailable');
          }
          if (keys.length == 3) {
            return CommandReply(
              dataJson: '{}',
              errorCode: 'resource-exhausted',
            );
          }
          return CommandReply(dataJson: '{}');
        },
      );
      await api.execute('submitPayout', {'amount': 100});
      await api.execute('submitPayout', {'amount': 100});
      await api.execute('submitPayout', {'amount': 100});
      await api.execute('submitPayout', {'amount': 100});
      expect(keys.toSet(), hasLength(1));
    },
  );
  test('account changes cannot reuse another user request key', () async {
    var uid = 'first';
    final keys = <String>[];
    final api = OperationsApi(
      userId: () => uid,
      transport: (_, _, key) async {
        keys.add(key);
        return CommandReply(dataJson: '{}', errorCode: 'unavailable');
      },
    );
    await api.execute('submitPayout', {'amount': 100});
    uid = 'second';
    await api.execute('submitPayout', {'amount': 100});
    expect(keys[0], isNot(keys[1]));
  });
  test(
    'unauthenticated and unconfigured actions never invoke transport',
    () async {
      final api = OperationsApi(
        userId: () => '',
        transport: (_, _, _) => throw StateError('Must not send'),
      );
      expect((await api.execute('createOrder', {})).isLeft(), isTrue);
      expect(
        (await OperationsApi(
          baseUrl: '',
          userId: () => 'customer',
        ).execute('createOrder', {})).isLeft(),
        isTrue,
      );
    },
  );
}
