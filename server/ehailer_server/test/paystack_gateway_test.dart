import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:ehailer_server/src/core/domain/operation_failure.dart';
import 'package:ehailer_server/src/features/payments/infrastructure/paystack_gateway.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  test(
    'initialization sends minor units and only trusts the Paystack checkout host',
    () async {
      var redirect = 'https://checkout.paystack.com/fixture';
      final gateway = PaystackGateway(
        client: MockClient((request) async {
          expect(request.headers['authorization'], 'Bearer sk_test_fixture');
          expect(request.followRedirects, isFalse);
          final body = jsonDecode(request.body) as Map;
          expect(body['amount'], '50501');
          expect(body['currency'], 'NGN');
          return http.Response(
            jsonEncode({
              'status': true,
              'data': {'reference': 'reference', 'authorization_url': redirect},
            }),
            200,
          );
        }),
        secret: 'sk_test_fixture',
        mode: 'test',
      );
      expect(
        (await gateway.initialize(
          reference: 'reference',
          email: 'payer@example.test',
          amountMinor: 50501,
        )).authorizationUrl,
        redirect,
      );
      for (final bad in [
        'https://checkout.paystack.com.attacker.test/path',
        'http://checkout.paystack.com/path',
        'https://user@checkout.paystack.com/path',
      ]) {
        redirect = bad;
        await expectLater(
          gateway.initialize(
            reference: 'reference',
            email: 'payer@example.test',
            amountMinor: 50501,
          ),
          throwsA(isA<OperationFailure>()),
        );
      }
    },
  );
  test('webhook signature authenticates exact raw bytes before parsing', () {
    const secret = 'sk_test_fixture';
    final gateway = PaystackGateway(
      client: MockClient((_) async => http.Response('', 500)),
      secret: secret,
      mode: 'test',
    );
    final bytes = utf8.encode('{"event":"charge.success"}');
    final signature = Hmac(
      sha512,
      utf8.encode(secret),
    ).convert(bytes).toString();
    expect(gateway.acceptsSignature(bytes, signature), isTrue);
    expect(gateway.acceptsSignature([...bytes, 32], signature), isFalse);
    expect(gateway.acceptsSignature(bytes, '0' * 128), isFalse);
    expect(gateway.acceptsSignature(bytes, null), isFalse);
  });
  test('provider errors never expose the raw response', () async {
    final gateway = PaystackGateway(
      client: MockClient(
        (_) async => http.Response('private provider details', 500),
      ),
      secret: 'sk_test_fixture',
      mode: 'test',
    );
    await expectLater(
      gateway.verify('reference'),
      throwsA(
        isA<OperationFailure>().having(
          (e) => e.message.contains('private provider'),
          'redacted',
          isFalse,
        ),
      ),
    );
  });
}
