import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/domain/failures/app_failure.dart';
import '../../../../core/presentation/utils/fp_framework.dart';
import '../providers/wallet_providers.dart';
import '../../domain/entities/wallet_top_up.dart';

/// Hosted checkout and verification are separate actions. Browser navigation is
/// never treated as proof of payment; durable server state supports app restarts.
class WalletTopUpDialog extends ConsumerStatefulWidget {
  final Future<bool> Function(Uri)? openCheckout;
  const WalletTopUpDialog({super.key, this.openCheckout});
  @override
  ConsumerState<WalletTopUpDialog> createState() => _WalletTopUpDialogState();
}

class _WalletTopUpDialogState extends ConsumerState<WalletTopUpDialog>
    with WidgetsBindingObserver {
  final _amount = TextEditingController(text: '1000');
  WalletTopUp? _topUp;
  String? _message;
  bool _busy = true;
  bool _opened = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _recover();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _amount.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _opened &&
        !_busy &&
        _topUp?.credited == false) {
      _verify();
    }
  }

  Future<void> _apply(Future<Either<AppFailure, WalletTopUp?>> request) async {
    final result = await request;
    if (!mounted) return;
    setState(() {
      _busy = false;
      result.fold((failure) => _message = failure.message, (value) {
        _topUp = value;
        _message = null;
        if (value != null) {
          _amount.text = (value.amountMinor / 100).toStringAsFixed(2);
        }
      });
    });
  }

  Future<void> _recover() =>
      _apply(ref.read(walletPaymentServiceProvider).recover());

  Future<void> _initialize() async {
    final text = _amount.text.trim();
    if (!RegExp(r'^\d{1,7}(\.\d{1,2})?$').hasMatch(text)) {
      setState(
        () =>
            _message = 'Enter an amount with no more than two decimal places.',
      );
      return;
    }
    final parts = text.split('.');
    final amountMinor =
        int.parse(parts[0]) * 100 +
        int.parse(parts.length == 1 ? '0' : parts[1].padRight(2, '0'));
    if (amountMinor < 10000 || amountMinor > 100000000) {
      setState(() => _message = 'Enter an amount between ₦100 and ₦1,000,000.');
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    await _apply(
      ref.read(walletPaymentServiceProvider).initialize(amountMinor),
    );
  }

  Future<void> _verify() async {
    final topUp = _topUp;
    if (topUp == null || _busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    await _apply(
      ref.read(walletPaymentServiceProvider).verify(topUp.reference),
    );
    if (mounted && _topUp?.credited == false && _message == null) {
      setState(
        () => _message =
            'Payment has not been confirmed yet. You can check again.',
      );
    }
  }

  Future<void> _open() async {
    final uri = _topUp?.authorizationUrl;
    if (uri == null) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final opened =
          await (widget.openCheckout?.call(uri) ??
              launchUrl(
                uri,
                mode: LaunchMode.externalApplication,
                webOnlyWindowName: '_blank',
              ));
      if (!mounted) return;
      setState(() {
        _opened = opened;
        _busy = false;
        if (!opened) {
          _message = 'Checkout could not be opened. Try Open Paystack again.';
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _message = 'Checkout could not be opened. Please retry.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final topUp = _topUp;
    return AlertDialog(
      title: Text(
        topUp?.credited == true ? 'Top-up confirmed' : 'Top up your wallet',
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 420,
          maxHeight: MediaQuery.sizeOf(context).height * .65,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (topUp?.isTest == true) ...[
                const Text(
                  'Test payment — use Paystack test details. No real money.',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
              ],
              if (topUp?.credited == true)
                Text(
                  '₦${(topUp!.amountMinor / 100).toStringAsFixed(2)} has been verified and added to your wallet.',
                )
              else ...[
                const Text(
                  'Pay securely on Paystack. Your balance updates only after the server confirms payment.',
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _amount,
                  enabled: !_busy && topUp == null,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Amount (NGN)',
                    prefixText: '₦',
                    helperText: 'Minimum ₦100',
                  ),
                ),
                if (topUp != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    topUp.status == 'initializing'
                        ? 'Checkout is being prepared. Check setup shortly.'
                        : 'Return here after checkout to check your payment.',
                  ),
                ],
              ],
              if (topUp != null) ...[
                const SizedBox(height: 16),
                SelectableText(
                  'Reference: ${topUp.reference}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              if (_busy)
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: LinearProgressIndicator(
                    semanticsLabel: 'Checking payment service',
                  ),
                ),
              if (_message != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(_message!, semanticsLabel: _message),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(topUp?.credited == true ? 'Done' : 'Close'),
        ),
        if (topUp == null || topUp.status == 'initializing')
          FilledButton(
            onPressed: _busy ? null : _initialize,
            child: Text(topUp == null ? 'Create checkout' : 'Check setup'),
          ),
        if (topUp != null && !topUp.credited) ...[
          if (topUp.authorizationUrl != null)
            FilledButton(
              onPressed: _busy ? null : _open,
              child: const Text('Open Paystack'),
            ),
          TextButton(
            onPressed: _busy ? null : _verify,
            child: const Text('Check payment status'),
          ),
          if (topUp.canRestart)
            TextButton(
              onPressed: _busy
                  ? null
                  : () => setState(() {
                      _topUp = null;
                      _message = null;
                    }),
              child: const Text('Start again'),
            ),
        ],
      ],
    );
  }
}
