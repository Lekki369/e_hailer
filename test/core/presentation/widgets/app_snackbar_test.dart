import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:e_hailer/app.dart';
import 'package:e_hailer/core/presentation/widgets/app_snackbar.dart';

void main() {
  Widget createTestWidget(Widget child) {
    return ScreenUtilInit(
      designSize: const Size(375, 812),
      builder: (_, __) => MaterialApp(
        scaffoldMessengerKey: appScaffoldMessengerKey,
        home: Scaffold(body: child),
      ),
    );
  }

  group('AppSnackBar Widget Tests', () {
    testWidgets('shows success snackbar with custom message and check icon',
        (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => AppSnackBar.showSuccess(
                context,
                'Order created successfully!',
              ),
              child: const Text('Show Success'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Success'));
      await tester.pump(); // Start animation
      await tester.pump(const Duration(milliseconds: 300)); // Complete animation

      expect(find.text('Order created successfully!'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    });

    testWidgets('shows error snackbar with alert icon and message',
        (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => AppSnackBar.showError(
                context,
                'Payment authorization failed',
              ),
              child: const Text('Show Error'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Error'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Payment authorization failed'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
    });

    testWidgets('shows warning snackbar with title and message',
        (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => AppSnackBar.showWarning(
                context,
                'Wallet balance is below minimum threshold.',
                title: 'Low Balance',
              ),
              child: const Text('Show Warning'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Warning'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Low Balance'), findsOneWidget);
      expect(
        find.text('Wallet balance is below minimum threshold.'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });

    testWidgets('shows global snackbar via appScaffoldMessengerKey without context',
        (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          ElevatedButton(
            onPressed: () => AppSnackBar.showGlobalSuccess(
              'Global notification received!',
              title: 'Incoming Dispatch',
            ),
            child: const Text('Show Global'),
          ),
        ),
      );

      await tester.tap(find.text('Show Global'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Incoming Dispatch'), findsOneWidget);
      expect(find.text('Global notification received!'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    });
  });
}
