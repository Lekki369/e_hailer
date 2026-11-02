import 'package:equatable/equatable.dart';

class WalletTopUp extends Equatable {
  final String reference, currency, mode, status;
  final int amountMinor;
  final Uri? authorizationUrl;
  const WalletTopUp({
    required this.reference,
    required this.currency,
    required this.mode,
    required this.status,
    required this.amountMinor,
    this.authorizationUrl,
  });

  bool get credited => status == 'credited';
  bool get canRestart =>
      {'failed', 'abandoned', 'initializationFailed'}.contains(status);
  bool get isTest => mode == 'test';

  factory WalletTopUp.fromMap(Map<String, dynamic> map) {
    final reference = map['reference'];
    final amount = map['amountMinor'];
    final rawUrl = map['authorizationUrl'];
    final url = rawUrl is String ? Uri.tryParse(rawUrl) : null;
    if (reference is! String ||
        !RegExp(r'^EH-TOPUP-[a-f0-9]{40}$').hasMatch(reference) ||
        amount is! int ||
        amount < 10000 ||
        amount > 100000000 ||
        map['currency'] != 'NGN' ||
        !{'test', 'live'}.contains(map['mode']) ||
        !{
          'initializing',
          'pending',
          'credited',
          'failed',
          'abandoned',
          'initializationFailed',
        }.contains(map['status']) ||
        (rawUrl != null &&
            (url == null ||
                url.scheme != 'https' ||
                url.host != 'checkout.paystack.com' ||
                url.userInfo.isNotEmpty ||
                url.hasPort))) {
      throw const FormatException('Invalid top-up response.');
    }
    return WalletTopUp(
      reference: reference,
      amountMinor: amount,
      currency: map['currency'] as String,
      mode: map['mode'] as String,
      status: map['status'] as String,
      authorizationUrl: url,
    );
  }

  Map<String, dynamic> toMap() => {
    'reference': reference,
    'amountMinor': amountMinor,
    'currency': currency,
    'mode': mode,
    'status': status,
    'authorizationUrl': authorizationUrl?.toString(),
  };

  @override
  List<Object?> get props => [
    reference,
    amountMinor,
    currency,
    mode,
    status,
    authorizationUrl,
  ];
}
