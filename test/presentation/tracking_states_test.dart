import 'dart:async';
import 'package:e_hailer/core/domain/failures/app_failure.dart';
import 'package:e_hailer/core/presentation/styles/app_theme.dart';
import 'package:e_hailer/features/delivery/domain/entities/public_delivery_tracking.dart';
import 'package:e_hailer/features/delivery/domain/value_objects/delivery_status.dart';
import 'package:e_hailer/features/delivery/presentation/providers/delivery_providers.dart';
import 'package:e_hailer/features/delivery/presentation/screens/public_tracking_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

const code = 'EH-0123456789ABCDEF0123456789ABCDEF';
typedef TrackingResult = Either<AppFailure, PublicDeliveryTracking>;

void main() {
  Future<void> showTracking(
    WidgetTester tester,
    Stream<TrackingResult> Function() stream, {
    bool initialCode = true,
  }) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          publicOrderTrackingStreamProvider(
            code,
          ).overrideWith((ref) => stream()),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: PublicTrackingScreen(
            initialTrackingNumber: initialCode ? code : null,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('empty and invalid input never requests private or public data', (
    tester,
  ) async {
    var calls = 0;
    await showTracking(tester, () {
      calls++;
      return const Stream.empty();
    }, initialCode: false);
    expect(find.text('Waiting for your tracking number'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'EH-short');
    await tester.tap(find.text('Track delivery'));
    await tester.pumpAndSettle();
    expect(
      find.text('Enter the complete tracking number from your booking.'),
      findsOneWidget,
    );
    expect(calls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pending lookup shows an accessible loading state', (
    tester,
  ) async {
    final controller = StreamController<TrackingResult>();
    addTearDown(controller.close);
    await showTracking(tester, () => controller.stream);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester
          .widget<CircularProgressIndicator>(
            find.byType(CircularProgressIndicator),
          )
          .semanticsLabel,
      'Loading delivery progress',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('transport errors offer retry without exposing raw details', (
    tester,
  ) async {
    var calls = 0;
    await showTracking(tester, () {
      calls++;
      return calls == 1
          ? Stream.error(StateError('private SDK context'))
          : Stream.value(
              right(
                PublicDeliveryTracking(
                  trackingNumber: code,
                  estimatedDurationMinutes: 25,
                  status: DeliveryStatus.delivered,
                  updatedAt: DateTime(2026),
                  timeline: const [],
                ),
              ),
            );
    });
    await tester.pumpAndSettle();
    expect(find.text('Tracking is unavailable'), findsOneWidget);
    expect(find.textContaining('private SDK context'), findsNothing);
    await tester.ensureVisible(find.text('Try again'));
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.byType(PublicTrackingDetails), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an expired or missing delivery gives recoverable feedback', (
    tester,
  ) async {
    await showTracking(
      tester,
      () => Stream.value(left(const OrderNotFoundFailure())),
    );
    await tester.pumpAndSettle();
    expect(find.text('We could not find that delivery'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.byType(PublicTrackingDetails), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
