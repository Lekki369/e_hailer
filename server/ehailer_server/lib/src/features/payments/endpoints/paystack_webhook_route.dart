import 'dart:convert';
import 'package:serverpod/serverpod.dart';
import '../../../core/domain/operation_failure.dart';
import '../domain/payment_service.dart';
import '../infrastructure/paystack_gateway.dart';

class PaystackWebhookRoute extends Route {
  final PaymentService payments;
  final PaystackGateway gateway;
  PaystackWebhookRoute(this.payments, this.gateway)
    : super(methods: {Method.post});

  @override
  Future<Result> handleCall(Session session, Request request) async {
    final signatures = request.headers['x-paystack-signature'];
    if (signatures == null || signatures.length != 1) return Response(401);
    try {
      final bytes = <int>[];
      await for (final part
          in request.body
              .read(maxLength: 65536)
              .timeout(const Duration(seconds: 10))) {
        bytes.addAll(part);
      }
      if (!gateway.acceptsSignature(bytes, signatures.single)) {
        return Response(401);
      }
      final event = jsonDecode(utf8.decode(bytes));
      if (event is! Map) return Response(400);
      if (event['event'] != 'charge.success') return Response.ok();
      final data = event['data'];
      final reference = data is Map ? data['reference'] : null;
      if (reference is! String || !PaymentService.validReference(reference)) {
        return Response.ok();
      }
      // Re-verify with Paystack; the event body itself never grants credit.
      await payments.verify(reference);
      return Response.ok();
    } on OperationFailure catch (failure) {
      if ({'payment-mismatch', 'payment-conflict'}.contains(failure.code)) {
        session.log(
          'Payment reconciliation requires review.',
          level: LogLevel.warning,
        );
        return Response(409);
      }
      return Response(503); // Retry transient provider/storage failures.
    } on FormatException {
      return Response(400);
    } on MaxBodySizeExceeded {
      return Response(413);
    } catch (_) {
      return Response(503);
    }
  }
}
