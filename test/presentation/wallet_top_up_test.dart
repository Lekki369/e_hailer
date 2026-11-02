import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:e_hailer/core/domain/failures/app_failure.dart';
import 'package:e_hailer/core/presentation/styles/app_assets.dart';
import 'package:e_hailer/core/presentation/styles/app_theme.dart';
import 'package:e_hailer/core/presentation/utils/fp_framework.dart';
import 'package:e_hailer/features/wallet/domain/entities/wallet_top_up.dart';
import 'package:e_hailer/features/wallet/infrastructure/wallet_payment_service.dart';
import 'package:e_hailer/features/wallet/presentation/providers/wallet_providers.dart';
import 'package:e_hailer/features/wallet/presentation/widgets/wallet_top_up_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

WalletTopUp topUp([String status = 'pending']) => WalletTopUp(
  reference: 'EH-TOPUP-${'a' * 40}',
  amountMinor: 50000,
  currency: 'NGN',
  mode: 'test',
  status: status,
  authorizationUrl: Uri.parse('https://checkout.paystack.com/fixture'),
);

class PaymentFixture implements WalletPaymentService {
  WalletTopUp? recovered;
  WalletTopUp verified = topUp();
  int checks = 0;
  final amounts = <int>[];
  Completer<Either<AppFailure, WalletTopUp?>>? pending;
  @override
  Future<Either<AppFailure, WalletTopUp?>> recover() async => right(recovered);
  @override
  Future<Either<AppFailure, WalletTopUp?>> initialize(int amountMinor) async {
    amounts.add(amountMinor);
    return pending?.future ?? right(topUp());
  }

  @override
  Future<Either<AppFailure, WalletTopUp?>> verify(String reference) async {
    checks++;
    return right(verified);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> showTopUp(
  WidgetTester tester,
  PaymentFixture service, {
  double scale = 1,
  Future<bool> Function(Uri)? open,
  GlobalKey? captureKey,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [walletPaymentServiceProvider.overrideWithValue(service)],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        builder: (context, child) => RepaintBoundary(
          key: captureKey,
          child: MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => WalletTopUpDialog(openCheckout: open),
              ),
              child: const Text('Top up'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Top up'));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final font = FontLoader('PlusJakartaSans')
      ..addFont(rootBundle.load(AppAssets.interfaceFont));
    await font.load();
  });
  test(
    'checkout responses reject foreign, insecure and credential-bearing URLs',
    () {
      final data = topUp().toMap();
      for (final url in [
        'https://attacker.example/pay',
        'http://checkout.paystack.com/pay',
        'https://user@checkout.paystack.com/pay',
      ]) {
        expect(
          () => WalletTopUp.fromMap({...data, 'authorizationUrl': url}),
          throwsFormatException,
        );
      }
      expect(WalletTopUp.fromMap(data), topUp());
    },
  );
  testWidgets(
    'amount parsing sends exact minor units and rejects excess decimals',
    (tester) async {
      final service = PaymentFixture();
      await showTopUp(tester, service);
      await tester.enterText(find.byType(TextField), '500.001');
      await tester.tap(find.text('Create checkout'));
      await tester.pumpAndSettle();
      expect(service.amounts, isEmpty);
      await tester.enterText(find.byType(TextField), '500.01');
      await tester.tap(find.text('Create checkout'));
      await tester.pumpAndSettle();
      expect(service.amounts, [50001]);
    },
  );
  testWidgets('opening hosted checkout never claims success', (tester) async {
    final service = PaymentFixture()..recovered = topUp();
    Uri? opened;
    await showTopUp(
      tester,
      service,
      open: (uri) async {
        opened = uri;
        return true;
      },
    );
    await tester.tap(find.text('Open Paystack'));
    await tester.pumpAndSettle();
    expect(opened?.host, 'checkout.paystack.com');
    expect(service.checks, 0);
    expect(find.text('Top-up confirmed'), findsNothing);
    expect(find.textContaining('Test payment'), findsOneWidget);
    await tester.tap(find.text('Check payment status'));
    await tester.pumpAndSettle();
    expect(find.text('Top-up confirmed'), findsNothing);
    service.verified = topUp('credited');
    await tester.tap(find.text('Check payment status'));
    await tester.pumpAndSettle();
    expect(find.text('Top-up confirmed'), findsOneWidget);
  });
  testWidgets(
    'pending checkout recovers without initializing another payment',
    (tester) async {
      final service = PaymentFixture()..recovered = topUp();
      await showTopUp(tester, service);
      expect(find.text('Open Paystack'), findsOneWidget);
      expect(service.amounts, isEmpty);
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    },
  );
  testWidgets('a delayed initialization can finish after closing the dialog', (
    tester,
  ) async {
    final service = PaymentFixture()..pending = Completer();
    await showTopUp(tester, service);
    await tester.tap(find.text('Create checkout'));
    await tester.pump();
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    service.pending!.complete(right(topUp()));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
  testWidgets('failed browser launch offers recovery without marking paid', (
    tester,
  ) async {
    final service = PaymentFixture()..recovered = topUp();
    await showTopUp(tester, service, open: (_) async => false);
    await tester.tap(find.text('Open Paystack'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Checkout could not be opened'), findsOneWidget);
    expect(find.text('Top-up confirmed'), findsNothing);
  });
  for (final width in [320.0, 600.0, 1280.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('hosted payment dialog fits $width with text scale $scale', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final boundary = GlobalKey();
        await showTopUp(
          tester,
          PaymentFixture()..recovered = topUp(),
          scale: scale,
          captureKey: boundary,
        );
        expect(tester.takeException(), isNull);
        expect(find.text('Check payment status').hitTestable(), findsOneWidget);
        if (const bool.fromEnvironment('CAPTURE_UI')) {
          await tester.runAsync(() async {
            final surface =
                boundary.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await surface.toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final file = File(
              '.cache/ui/topup-${width.toInt()}-${scale.toInt()}x.png',
            );
            file.parent.createSync(recursive: true);
            file.writeAsBytesSync(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
      });
    }
  }
}
