import 'dart:io';
import 'package:firebase_admin_sdk/firebase_admin_sdk.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:ehailer_server/src/core/domain/command_store.dart';
import 'package:ehailer_server/src/core/domain/operation_failure.dart';
import 'package:ehailer_server/src/core/infrastructure/firestore_command_store.dart';
import 'package:ehailer_server/src/features/payments/domain/payment_gateway.dart';
import 'package:ehailer_server/src/features/payments/domain/payment_service.dart';
import 'support/memory_command_store.dart';

class FakeGateway implements PaymentGateway {
  @override
  String get mode => 'test';
  int initialized = 0, verified = 0;
  bool failInitialize = false;
  String status = 'success';
  String transactionId = '123';
  Json overrides = {};
  Future<void> Function(String)? afterInitialize;
  final Map<String, Json> requests = {};
  @override
  Future<HostedCheckout> initialize({
    required String reference,
    required String email,
    required int amountMinor,
  }) async {
    initialized++;
    requests[reference] = {'email': email, 'amountMinor': amountMinor};
    await afterInitialize?.call(reference);
    if (failInitialize) {
      throw const OperationFailure('payment-unavailable', 'Unavailable');
    }
    return HostedCheckout(reference, 'https://checkout.paystack.com/fixture');
  }

  @override
  Future<VerifiedPayment> verify(String reference) async {
    verified++;
    final input = {...requests[reference]!, ...overrides};
    return VerifiedPayment(
      reference: overrides['reference'] as String? ?? reference,
      status: status,
      transactionId: transactionId,
      mode: overrides['mode'] as String? ?? mode,
      currency: overrides['currency'] as String? ?? 'NGN',
      email: input['email'] as String,
      amountMinor: input['amountMinor'] as int,
    );
  }
}

void main() {
  final emulator = Platform.environment['FIRESTORE_EMULATOR_HOST'];
  late CommandStore store;
  late FakeGateway gateway;
  late PaymentService payments;
  var serial = 0;
  String key() => 'payment-request-${++serial}';
  Future<Json?> read(String path) => store.transaction((tx) => tx.get(path));
  Future<Json> initialize({
    String uid = 'customer',
    int amount = 50000,
    String? requestId,
  }) => payments.initialize(uid, amount, requestId ?? key());
  Matcher failure(String code) =>
      isA<OperationFailure>().having((e) => e.code, 'code', code);
  setUp(() async {
    if (emulator != null) {
      if (!emulator.startsWith('127.0.0.1:') &&
          !emulator.startsWith('localhost:')) {
        throw StateError('Local emulators only.');
      }
      final response = await http.delete(
        Uri.parse(
          'http://$emulator/emulator/v1/projects/demo-ehailer/databases/(default)/documents',
        ),
      );
      expect(response.statusCode, 200);
      final app = FirebaseApp.initializeApp(
        name: key(),
        options: AppOptions(projectId: 'demo-ehailer'),
      );
      store = FirestoreCommandStore(app.firestore());
      addTearDown(() => FirebaseApp.deleteApp(app));
    } else {
      store = MemoryCommandStore();
    }
    gateway = FakeGateway();
    payments = PaymentService(store: store, gateway: gateway);
    await store.transaction((tx) async {
      for (final uid in ['customer', 'other', 'admin']) {
        tx.set('users/$uid', {
          'uid': uid,
          'role': uid == 'admin' ? 'admin' : 'customer',
          'email': '$uid@example.test',
          'walletBalance': 100,
        });
      }
    });
  });

  test('initialization and restart recovery never credit a wallet', () async {
    final intent = await initialize();
    expect(intent['status'], 'pending');
    expect((await read('users/customer'))!['walletBalance'], 100);
    final recovered = await payments.execute(
      'getWalletTopUp',
      'customer',
      {},
      key(),
    );
    expect((recovered['topUp'] as Map)['reference'], intent['reference']);
    expect((recovered['topUp'] as Map).containsKey('email'), isFalse);
  });
  test('concurrent creation and retries reuse one active checkout', () async {
    final intents = await Future.wait([
      initialize(),
      initialize(),
      initialize(),
    ]);
    expect(intents.map((e) => e['reference']).toSet(), hasLength(1));
    expect(gateway.initialized, 1);
    expect((await initialize())['authorizationUrl'], isNotNull);
    expect(gateway.initialized, 1);
  });
  test('request key reuse cannot change the charged amount', () async {
    final request = key();
    await initialize(requestId: request);
    await expectLater(
      initialize(amount: 60000, requestId: request),
      throwsA(failure('conflict')),
    );
    await expectLater(initialize(amount: 60000), throwsA(failure('conflict')));
  });
  test(
    'provider initialization failure creates no ledger and permits a new attempt',
    () async {
      gateway.failInitialize = true;
      await expectLater(
        initialize(),
        throwsA(failure('payment-initialization-failed')),
      );
      expect((await read('users/customer'))!['walletBalance'], 100);
      gateway.failInitialize = false;
      expect((await initialize())['authorizationUrl'], isNotNull);
    },
  );
  test('ownership is checked before contacting the provider', () async {
    final intent = await initialize();
    await expectLater(
      payments.verify(intent['reference'] as String, uid: 'other'),
      throwsA(failure('permission-denied')),
    );
    expect(gateway.verified, 0);
  });
  test('pending payments do not create wallet value', () async {
    final intent = await initialize();
    gateway.status = 'pending';
    expect(
      (await payments.verify(
        intent['reference'] as String,
        uid: 'customer',
      ))!['status'],
      'pending',
    );
    expect((await read('users/customer'))!['walletBalance'], 100);
    expect(
      await read('users/customer/transactions/topup-${intent['reference']}'),
      isNull,
    );
  });
  for (final mismatch in <Json>[
    {'amountMinor': 1},
    {'currency': 'USD'},
    {'mode': 'live'},
    {'email': 'other@example.test'},
    {'reference': 'wrong-reference'},
  ]) {
    test('verified payment must match ${mismatch.keys.single}', () async {
      final intent = await initialize();
      gateway.overrides = mismatch;
      await expectLater(
        payments.verify(intent['reference'] as String),
        throwsA(failure('payment-mismatch')),
      );
      expect((await read('users/customer'))!['walletBalance'], 100);
    });
  }
  test('webhook and client verification races credit exactly once', () async {
    final intent = await initialize();
    final reference = intent['reference'] as String;
    await Future.wait([
      payments.verify(reference),
      payments.verify(reference, uid: 'customer'),
      payments.verify(reference),
    ]);
    expect((await read('users/customer'))!['walletBalance'], 600);
    expect(
      (await read('users/customer/transactions/topup-$reference'))!['amount'],
      500,
    );
    expect((await read('paymentIntents/$reference'))!['status'], 'credited');
    expect((await read('users/customer'))!['pendingTopUpReference'], isNull);
  });
  test('one provider transaction cannot fund different top-ups', () async {
    final first = await initialize();
    await payments.verify(first['reference'] as String);
    final other = await initialize(uid: 'other');
    await expectLater(
      payments.verify(other['reference'] as String),
      throwsA(failure('payment-conflict')),
    );
    expect((await read('users/other'))!['walletBalance'], 100);
  });
  test('late settlement preserves a newer active checkout', () async {
    final first = await initialize();
    gateway.status = 'abandoned';
    await payments.verify(first['reference'] as String);
    final second = await initialize(amount: 60000);
    gateway.status = 'success';
    await payments.verify(first['reference'] as String);
    expect(
      (await read('users/customer'))!['pendingTopUpReference'],
      second['reference'],
    );
    gateway.transactionId = '124';
    await payments.verify(second['reference'] as String);
    expect((await read('users/customer'))!['walletBalance'], 1200);
  });
  test(
    'a webhook during initialization cannot be overwritten by pending state',
    () async {
      gateway.afterInitialize = (reference) async {
        await payments.verify(reference);
      };
      final result = await initialize();
      expect(result['status'], 'credited');
      expect((await read('users/customer'))!['walletBalance'], 600);
    },
  );
  test(
    'unrelated merchant references do not contact provider or create wallets',
    () async {
      expect(await payments.verify('EH-TOPUP-${'a' * 40}'), isNull);
      expect(gateway.verified, 0);
    },
  );
  test(
    'a failed initialization response cannot undo a verified credit',
    () async {
      gateway.failInitialize = true;
      gateway.afterInitialize = (reference) async {
        await payments.verify(reference);
      };
      expect((await initialize())['status'], 'credited');
      expect((await read('users/customer'))!['walletBalance'], 600);
    },
  );
  test(
    'a corrupted pending pointer cannot expose another account checkout',
    () async {
      final other = await initialize(uid: 'other');
      await store.transaction((tx) async {
        tx.update('users/customer', {
          'pendingTopUpReference': other['reference'],
        });
      });
      await expectLater(initialize(), throwsA(failure('permission-denied')));
      await expectLater(
        payments.execute('getWalletTopUp', 'customer', {}, key()),
        throwsA(failure('permission-denied')),
      );
      expect(gateway.initialized, 1);
    },
  );
  test(
    'amount bounds and roles are validated before provider initialization',
    () async {
      for (final amount in [0, 9999, 100000001]) {
        await expectLater(
          initialize(amount: amount),
          throwsA(failure('invalid-argument')),
        );
      }
      await expectLater(
        initialize(uid: 'admin'),
        throwsA(failure('permission-denied')),
      );
      expect(gateway.initialized, 0);
    },
  );
}
