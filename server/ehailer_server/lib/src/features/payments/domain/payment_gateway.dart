import 'package:equatable/equatable.dart';

abstract interface class PaymentGateway {
  String get mode;
  Future<HostedCheckout> initialize({
    required String reference,
    required String email,
    required int amountMinor,
  });
  Future<VerifiedPayment> verify(String reference);
}

class HostedCheckout extends Equatable {
  final String reference;
  final String authorizationUrl;
  const HostedCheckout(this.reference, this.authorizationUrl);
  @override
  List<Object> get props => [reference, authorizationUrl];
}

class VerifiedPayment extends Equatable {
  final String reference, status, transactionId, mode, currency, email;
  final int amountMinor;
  const VerifiedPayment({
    required this.reference,
    required this.status,
    required this.transactionId,
    required this.mode,
    required this.currency,
    required this.email,
    required this.amountMinor,
  });
  @override
  List<Object> get props => [
    reference,
    status,
    transactionId,
    mode,
    currency,
    email,
    amountMinor,
  ];
}
