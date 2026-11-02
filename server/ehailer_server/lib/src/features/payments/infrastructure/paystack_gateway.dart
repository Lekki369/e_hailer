import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import '../../../core/domain/operation_failure.dart';
import '../domain/payment_gateway.dart';

class PaystackGateway implements PaymentGateway {
  final http.Client client;
  final String _secret;
  @override
  final String mode;
  final Uri baseUrl;
  final String? callbackUrl;
  PaystackGateway({
    required this.client,
    required this._secret,
    required this.mode,
    Uri? baseUrl,
    this.callbackUrl,
  }) : baseUrl = baseUrl ?? Uri.parse('https://api.paystack.co/');

  Future<Json> _request(String path, {Json? body}) async {
    try {
      final request =
          http.Request(body == null ? 'GET' : 'POST', baseUrl.resolve(path))
            ..followRedirects = false
            ..headers.addAll({
              'authorization': 'Bearer $_secret',
              'content-type': 'application/json',
            });
      if (body != null) request.body = jsonEncode(body);
      final response = await client
          .send(request)
          .timeout(const Duration(seconds: 10));
      final bytes = <int>[];
      await for (final part in response.stream.timeout(
        const Duration(seconds: 10),
      )) {
        bytes.addAll(part);
        if (bytes.length > 262144) throw const FormatException();
      }
      final value = jsonDecode(utf8.decode(bytes));
      if (response.statusCode != 200 ||
          value is! Map ||
          value['status'] != true ||
          value['data'] is! Map) {
        throw const FormatException();
      }
      return Json.from(value['data'] as Map);
    } catch (_) {
      throw const OperationFailure(
        'payment-unavailable',
        'The payment provider could not confirm this request. Please retry.',
      );
    }
  }

  @override
  Future<HostedCheckout> initialize({
    required String reference,
    required String email,
    required int amountMinor,
  }) async {
    final value = await _request(
      'transaction/initialize',
      body: {
        'reference': reference,
        'email': email,
        'amount': amountMinor.toString(),
        'currency': 'NGN',
        if (callbackUrl != null) 'callback_url': callbackUrl,
        'metadata': {'walletReference': reference},
      },
    );
    final uri = Uri.tryParse(value['authorization_url']?.toString() ?? '');
    requireCondition(
      value['reference'] == reference &&
          uri != null &&
          uri.scheme == 'https' &&
          uri.host == 'checkout.paystack.com' &&
          uri.userInfo.isEmpty &&
          !uri.hasPort,
      'The provider returned an invalid checkout session.',
      'payment-unavailable',
    );
    return HostedCheckout(reference, uri.toString());
  }

  @override
  Future<VerifiedPayment> verify(String reference) async {
    final value = await _request(
      'transaction/verify/${Uri.encodeComponent(reference)}',
    );
    final customer = value['customer'];
    final amount = value['amount'];
    requireCondition(
      amount is int &&
          value['id'] is int &&
          customer is Map &&
          value['reference'] is String &&
          value['status'] is String &&
          value['domain'] is String &&
          value['currency'] is String &&
          customer['email'] is String,
      'The payment provider returned an incomplete result.',
      'payment-unavailable',
    );
    return VerifiedPayment(
      reference: value['reference'] as String,
      status: value['status'] as String,
      transactionId: value['id'].toString(),
      mode: value['domain'] as String,
      currency: value['currency'] as String,
      email: (customer as Map)['email'] as String,
      amountMinor: amount as int,
    );
  }

  bool acceptsSignature(List<int> body, String? signature) {
    if (signature == null ||
        !RegExp(r'^[a-fA-F0-9]{128}$').hasMatch(signature)) {
      return false;
    }
    final expected = Hmac(
      sha512,
      utf8.encode(_secret),
    ).convert(body).toString();
    final supplied = signature.toLowerCase();
    var difference = 0;
    for (var i = 0; i < expected.length; i++) {
      difference |= expected.codeUnitAt(i) ^ supplied.codeUnitAt(i);
    }
    return difference == 0;
  }
}
