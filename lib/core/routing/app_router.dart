import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../features/auth/domain/user_entity.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/delivery/presentation/screens/consignment_creation_screen.dart';
import '../../features/delivery/presentation/screens/customer_home_screen.dart';
import '../../features/delivery/presentation/screens/driver_dashboard_screen.dart';
import '../../features/delivery/presentation/screens/express_booking_screen.dart';
import '../../features/delivery/presentation/screens/order_tracking_screen.dart';
import 'app_routes.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authStateAsync = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: AppRoutes.customerHomePath,
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final isLoggedIn = authStateAsync.value != null;
      final isLoggingIn = state.matchedLocation == AppRoutes.loginPath;

      if (!isLoggedIn) {
        return isLoggingIn ? null : AppRoutes.loginPath;
      }

      if (isLoggingIn) {
        final userProfile = ref.read(currentUserProfileProvider).value;
        if (userProfile?.role == UserRole.driver) {
          return AppRoutes.driverDashboardPath;
        }
        return AppRoutes.customerHomePath;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.loginPath,
        name: AppRoutes.loginName,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.customerHomePath,
        name: AppRoutes.customerHomeName,
        builder: (context, state) => const CustomerHomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.expressBookingPath,
        name: AppRoutes.expressBookingName,
        builder: (context, state) => const ExpressBookingScreen(),
      ),
      GoRoute(
        path: AppRoutes.consignmentCreationPath,
        name: AppRoutes.consignmentCreationName,
        builder: (context, state) => const ConsignmentCreationScreen(),
      ),
      GoRoute(
        path: AppRoutes.driverDashboardPath,
        name: AppRoutes.driverDashboardName,
        builder: (context, state) => const DriverDashboardScreen(),
      ),
      GoRoute(
        path: AppRoutes.orderTrackingPath,
        name: AppRoutes.orderTrackingName,
        builder: (context, state) {
          final orderId = state.pathParameters['orderId'] ?? '';
          return OrderTrackingScreen(orderId: orderId);
        },
      ),
    ],
  );
});

class GoRouterRefreshStream extends ChangeNotifier {
  late final StreamSubscription<dynamic> _subscription;

  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
