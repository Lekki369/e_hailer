@Timeout(Duration(minutes: 3))
library;

import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:firebase_admin_sdk/firebase_admin_sdk.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

/// Exercises the actual generated Serverpod HTTP endpoint with Auth emulator JWTs.
void main() {
  final emulator = Platform.environment['FIREBASE_AUTH_EMULATOR_HOST'];
  if (emulator == null) {
    test(
      'API authentication requires local Firebase emulators',
      () {},
      skip: 'Run bash tool/test_emulators.sh',
    );
    return;
  }
  late Process process;
  late FirebaseApp admin;
  late String uid, token;
  late HttpServer routes;
  late HttpServer paystack;
  final providerPayments = <String, Map<String, dynamic>>{};
  final logs = StringBuffer();
  Future<http.Response> call({
    String? bearer,
    String command = 'quoteOrder',
    Map<String, dynamic> payload = const {},
  }) => http.post(
    Uri.parse('http://127.0.0.1:8797/operations/execute'),
    headers: {
      'content-type': 'application/json',
      if (bearer != null) 'authorization': 'Bearer $bearer',
    },
    body: jsonEncode({
      'command': command,
      'payload': jsonEncode(payload),
      'requestId': 'api-test-${DateTime.now().microsecondsSinceEpoch}',
    }),
  );
  setUpAll(() async {
    if (!emulator.startsWith('127.0.0.1:') &&
        !emulator.startsWith('localhost:')) {
      throw StateError('Tests require local emulators.');
    }
    admin = FirebaseApp.initializeApp(
      name: 'api-test',
      options: AppOptions(projectId: 'demo-ehailer'),
    );
    final signedUp = await http.post(
      Uri.parse(
        'http://$emulator/identitytoolkit.googleapis.com/v1/accounts:signUp?key=emulator-key',
      ),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({
        'email': 'api-${DateTime.now().microsecondsSinceEpoch}@example.test',
        'password': 'emulator-password-only',
        'returnSecureToken': true,
      }),
    );
    expect(signedUp.statusCode, 200);
    final credentials = jsonDecode(signedUp.body) as Map;
    uid = credentials['localId'] as String;
    token = credentials['idToken'] as String;
    await admin.firestore().doc('users/$uid').set({
      'uid': uid,
      'role': 'customer',
      'fullName': 'API Test',
      'email': 'payer@example.test',
      'phone': '08012345678',
      'walletBalance': 10000,
    });
    routes = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    routes.listen((request) {
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'code': 'Ok',
          'routes': [
            {'distance': 10000, 'duration': 1500},
          ],
        }),
      );
      request.response.close();
    });
    paystack = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    paystack.listen((request) async {
      request.response.headers.contentType = ContentType.json;
      if (request.uri.path == '/transaction/initialize') {
        final input =
            jsonDecode(await utf8.decoder.bind(request).join()) as Map;
        final reference = input['reference'] as String;
        providerPayments[reference] = {
          'id': providerPayments.length + 1000,
          'reference': reference,
          'status': 'success',
          'domain': 'test',
          'currency': 'NGN',
          'amount': int.parse(input['amount'] as String),
          'customer': {'email': input['email']},
        };
        request.response.write(
          jsonEncode({
            'status': true,
            'data': {
              'reference': reference,
              'authorization_url': 'https://checkout.paystack.com/fixture',
            },
          }),
        );
      } else {
        request.response.write(
          jsonEncode({
            'status': true,
            'data': providerPayments[request.uri.pathSegments.last],
          }),
        );
      }
      await request.response.close();
    });
    process = await Process.start(
      Platform.resolvedExecutable,
      ['run', 'bin/main.dart', '--mode=test'],
      environment: {
        ...Platform.environment,
        'FIREBASE_PROJECT_ID': 'demo-ehailer',
        'OSRM_BASE_URL': 'http://127.0.0.1:${routes.port}',
        'PAYSTACK_SECRET_KEY': 'sk_test_fixture',
        'PAYSTACK_MODE': 'test',
        'PAYSTACK_BASE_URL': 'http://127.0.0.1:${paystack.port}/',
      },
    );
    process.stdout.transform(utf8.decoder).listen(logs.write);
    process.stderr.transform(utf8.decoder).listen(logs.write);
    // Cold Dart native-asset hooks can take over a minute on developer machines.
    // Stop immediately if the process exits instead of hiding a startup error.
    int? startupExit;
    process.exitCode.then((code) => startupExit = code);
    final deadline = DateTime.now().add(const Duration(minutes: 2));
    while (DateTime.now().isBefore(deadline)) {
      if (startupExit != null) {
        fail('Local API exited with code $startupExit: $logs');
      }
      try {
        await call().timeout(const Duration(seconds: 1));
        return;
      } catch (_) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
    }
    fail('Local API did not start: $logs');
  });
  setUp(() async {
    await admin
        .firestore()
        .doc('apiQuotas/${sha256.convert(utf8.encode(uid))}')
        .delete();
    await admin.firestore().doc('users/$uid').update({
      'walletBalance': 10000,
      'pendingTopUpReference': null,
    });
  });
  tearDownAll(() async {
    process.kill();
    await process.exitCode.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        process.kill(ProcessSignal.sigkill);
        return -1;
      },
    );
    await routes.close(force: true);
    await paystack.close(force: true);
    await FirebaseApp.deleteApp(admin);
  });
  test(
    'HTTP requests enforce quotas before invalid commands and payment work',
    () async {
      final quota = admin.firestore().doc(
        'apiQuotas/${sha256.convert(utf8.encode(uid))}',
      );
      final future = DateTime.now()
          .add(const Duration(minutes: 1))
          .millisecondsSinceEpoch;
      // Seed durable exhausted buckets. Wall-clock HTTP loops refill on a slow
      // machine; exact burst/refill counts use an injected clock in unit tests.
      await quota.set({
        'actions': {'tokens': 0, 'at': future},
      });
      final blockedAction = await call(
        bearer: token,
        command: 'unknown-new-key',
      );
      expect(
        (jsonDecode(blockedAction.body) as Map)['errorCode'],
        'resource-exhausted',
      );
      final payment = await call(
        bearer: token,
        command: 'initializeWalletTopUp',
        payload: {'amountMinor': 1},
      );
      expect(
        (jsonDecode(payment.body) as Map)['errorCode'],
        'invalid-argument',
      );
      await quota.set({
        'funding': {'tokens': 0, 'at': future},
      });
      final blockedPayment = await call(
        bearer: token,
        command: 'initializeWalletTopUp',
        payload: {'amountMinor': 1},
      );
      expect(
        (jsonDecode(blockedPayment.body) as Map)['errorCode'],
        'resource-exhausted',
      );
      await quota.set({
        'all': {'tokens': 0, 'at': future},
      });
      final blockedRead = await call(bearer: token, command: 'getWalletTopUp');
      expect(
        (jsonDecode(blockedRead.body) as Map)['errorCode'],
        'resource-exhausted',
      );
    },
  );

  test(
    'signed webhook and authenticated verification settle a hosted top-up once',
    () async {
      final initialized = await call(
        bearer: token,
        command: 'initializeWalletTopUp',
        payload: {'amountMinor': 50000},
      );
      expect(initialized.statusCode, 200);
      final reply = jsonDecode(initialized.body) as Map;
      expect(reply['errorCode'], isNull);
      final intent =
          (jsonDecode(reply['dataJson'] as String) as Map)['topUp'] as Map;
      final reference = intent['reference'] as String;
      expect(
        (await admin.firestore().doc('users/$uid').get())
            .data()!['walletBalance'],
        10000,
      );
      final body = jsonEncode({
        'event': 'charge.success',
        'data': {'reference': reference, 'amount': 999999999},
      });
      final signature = Hmac(
        sha512,
        utf8.encode('sk_test_fixture'),
      ).convert(utf8.encode(body)).toString();
      Future<http.Response> webhook(String signature, String payload) =>
          http.post(
            Uri.parse('http://127.0.0.1:8799/payments/paystack/webhook'),
            headers: {
              'content-type': 'application/json',
              'x-paystack-signature': signature,
            },
            body: payload,
          );
      expect((await webhook('0' * 128, body)).statusCode, 401);
      expect((await webhook(signature, '$body ')).statusCode, 401);
      expect(
        (await admin.firestore().doc('users/$uid').get())
            .data()!['walletBalance'],
        10000,
      );
      final responses = await Future.wait([
        webhook(signature, body),
        webhook(signature, body),
        call(
          bearer: token,
          command: 'verifyWalletTopUp',
          payload: {'reference': reference},
        ),
      ]);
      expect(responses.map((e) => e.statusCode), everyElement(200));
      expect(
        (await admin.firestore().doc('users/$uid').get())
            .data()!['walletBalance'],
        10500,
      );
      final ledger = await admin
          .firestore()
          .doc('users/$uid/transactions/topup-$reference')
          .get();
      expect(ledger.data()!['amount'], 500);
      final recovered = await call(bearer: token, command: 'getWalletTopUp');
      expect(
        (jsonDecode((jsonDecode(recovered.body) as Map)['dataJson'] as String)
            as Map)['topUp'],
        isNull,
      );
    },
  );
  test('missing and forged tokens cannot invoke operations', () async {
    final health = await http.get(Uri.parse('http://127.0.0.1:8799/healthz'));
    expect(health.statusCode, 200);
    for (final bearer in [null, 'forged-token']) {
      final response = await call(bearer: bearer);
      expect(response.statusCode, anyOf(401, 403));
    }
  });
  test(
    'verified Firebase UID reaches quote, booking and redacted persistence',
    () async {
      final input = {
        'type': 'express',
        'vehicleType': 'bike',
        'paymentMethod': 'wallet',
        'pickupLocation': {
          'latitude': 6.52,
          'longitude': 3.37,
          'address': 'Origin',
          'contactName': 'Sender',
          'contactPhone': '08012345678',
        },
        'dropoffLocation': {
          'latitude': 6.55,
          'longitude': 3.4,
          'address': 'Destination',
          'contactName': 'Recipient',
          'contactPhone': '08012345679',
        },
        'parcel': {'category': 'parcel', 'weightKg': 2},
      };
      final quoteResponse = await call(bearer: token, payload: input);
      expect(quoteResponse.statusCode, 200, reason: quoteResponse.body);
      final quoteReply = jsonDecode(quoteResponse.body) as Map;
      expect(quoteReply['errorCode'], isNull, reason: quoteResponse.body);
      final quote = jsonDecode(quoteReply['dataJson'] as String) as Map;
      final booked = await call(
        bearer: token,
        command: 'createOrder',
        payload: {
          ...input,
          'quoteId': quote['id'],
          'customerId': 'forged-customer',
        },
      );
      expect(booked.statusCode, 200, reason: booked.body);
      final reply = jsonDecode(booked.body) as Map;
      expect(reply['errorCode'], isNull, reason: booked.body);
      final order = jsonDecode(reply['dataJson'] as String) as Map;
      expect(order['customerId'], uid);
      expect(order.containsKey('recipientSecurityOtp'), isFalse);
      expect(
        (await admin.firestore().doc('users/$uid').get())
            .data()!['walletBalance'],
        8300,
      );
    },
  );
  test(
    'verified customers still cannot perform administrative commands',
    () async {
      final response = await call(
        bearer: token,
        command: 'assignOrders',
        payload: {
          'orderIds': ['order'],
          'driverId': 'driver',
          'role': 'admin',
        },
      );
      expect(response.statusCode, 200);
      expect(
        (jsonDecode(response.body) as Map)['errorCode'],
        'permission-denied',
      );
    },
  );
}
