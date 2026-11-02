import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:e_hailer/core/presentation/styles/app_assets.dart';
import 'package:e_hailer/core/presentation/styles/app_theme.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:e_hailer/core/presentation/widgets/adaptive_layout.dart';
import 'package:e_hailer/features/auth/domain/user_entity.dart';
import 'package:e_hailer/features/auth/presentation/providers/auth_providers.dart';
import 'package:e_hailer/features/auth/presentation/screens/login_screen.dart';
import 'package:e_hailer/features/auth/presentation/screens/profile_screen.dart';
import 'package:e_hailer/features/delivery/presentation/providers/delivery_providers.dart';
import 'package:e_hailer/features/delivery/presentation/providers/dispute_providers.dart';
import 'package:e_hailer/features/delivery/presentation/screens/booking_screen.dart';
import 'package:e_hailer/features/delivery/presentation/screens/customer_home_screen.dart';
import 'package:e_hailer/features/delivery/presentation/screens/driver_dashboard_screen.dart';
import 'package:e_hailer/features/delivery/presentation/screens/public_tracking_screen.dart';
import 'package:e_hailer/features/delivery/domain/entities/public_delivery_tracking.dart';
import 'package:e_hailer/features/delivery/domain/value_objects/delivery_status.dart';
import 'package:e_hailer/features/delivery/domain/value_objects/delivery_type.dart';
import 'package:e_hailer/features/admin/domain/entities/dispatch_metrics.dart';
import 'package:e_hailer/features/admin/presentation/providers/admin_providers.dart';
import 'package:e_hailer/features/admin/presentation/screens/admin_dashboard_screen.dart';
import 'package:e_hailer/features/wallet/presentation/providers/wallet_providers.dart';
import 'package:e_hailer/features/wallet/presentation/screens/wallet_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final loader = FontLoader('PlusJakartaSans')
      ..addFont(rootBundle.load(AppAssets.interfaceFont));
    await loader.load();
    // Flutter bundles this framework font outside the application's assets.
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  final screens = <String, Widget>{
    'login': const LoginScreen(),
    'booking': const BookingScreen(type: DeliveryType.consignment),
    'customer': const CustomerHomeScreen(),
    'driver': const DriverDashboardScreen(),
    'operations': const AdminDashboardScreen(),
    'wallet': const WalletScreen(),
    'driver-profile': const ProfileScreen(),
    'support-profile': const ProfileScreen(),
    'tracking': Scaffold(
      body: AdaptiveContent(
        child: PublicTrackingDetails(
          tracking: PublicDeliveryTracking(
            trackingNumber: 'EH-0123456789ABCDEF0123456789ABCDEF',
            status: DeliveryStatus.inTransit,
            estimatedDurationMinutes: 25,
            updatedAt: DateTime(2026, 10, 29, 10),
            timeline: [
              PublicTrackingEvent(
                DeliveryStatus.created,
                DateTime(2026, 10, 29, 9),
              ),
              PublicTrackingEvent(
                DeliveryStatus.inTransit,
                DateTime(2026, 10, 29, 10),
              ),
            ],
          ),
        ),
      ),
    ),
  };
  for (final entry in screens.entries) {
    for (final width in [320.0, 600.0, 1280.0]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('${entry.key} fits $width with text scale $scale', (
          tester,
        ) async {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final user = UserEntity(
            uid: 'user',
            fullName: 'Olamilekan Example Customer',
            email: 'customer@example.test',
            phone: '08012345678',
            role: entry.key == 'driver' || entry.key == 'driver-profile'
                ? UserRole.driver
                : entry.key == 'operations'
                ? UserRole.admin
                : entry.key == 'support-profile'
                ? UserRole.support
                : UserRole.customer,
            createdAt: DateTime(2026),
            walletBalance: 123456.78,
          );
          final boundary = GlobalKey();
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                currentUserProfileProvider.overrideWith(
                  (ref) => Stream.value(user),
                ),
                customerOrdersStreamProvider(
                  'user',
                ).overrideWith((ref) => Stream.value([])),
                driverActiveOrdersStreamProvider(
                  'user',
                ).overrideWith((ref) => Stream.value([])),
                availableOrdersStreamProvider.overrideWith(
                  (ref) => Stream.value([]),
                ),
                allOrdersStreamProvider.overrideWith((ref) => Stream.value([])),
                dispatchMetricsStreamProvider.overrideWith(
                  (ref) => Stream.value(const DispatchMetrics()),
                ),
                pendingDisputeCountProvider.overrideWith((ref) => 0),
                userTransactionsStreamProvider(
                  'user',
                ).overrideWith((ref) => Stream.value([])),
              ],
              child: ScreenUtilInit(
                designSize: const Size(375, 812),
                enableScaleWH: () => false,
                enableScaleText: () => false,
                builder: (_, _) => MaterialApp(
                  theme: AppTheme.lightTheme,
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: TextScaler.linear(scale)),
                    child: child!,
                  ),
                  home: RepaintBoundary(key: boundary, child: entry.value),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          if (entry.key == 'support-profile') {
            expect(find.text(UserRole.support.label), findsOneWidget);
          }
          if (entry.key == 'driver-profile') {
            expect(find.byType(ChoiceChip), findsNWidgets(4));
            await tester.ensureVisible(find.text('Update Vehicle Settings'));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }
          if (const bool.fromEnvironment('CAPTURE_UI') &&
              scale == 1 &&
              (width == 320 || width == 1280)) {
            await tester.runAsync(() async {
              final surface =
                  boundary.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary;
              final image = await surface.toImage();
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final file = File('.cache/ui/${entry.key}-${width.toInt()}.png');
              file.parent.createSync(recursive: true);
              file.writeAsBytesSync(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
        });
      }
    }
  }
}
