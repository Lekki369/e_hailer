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

final appRouterProvider = Provider<GoRouter>((ref) {
  final authStateAsync = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/home',
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final isLoggedIn = authStateAsync.value != null;
      final isLoggingIn = state.matchedLocation == '/login';

      if (!isLoggedIn) {
        return isLoggingIn ? null : '/login';
      }

      if (isLoggingIn) {
        final userProfile = ref.read(currentUserProfileProvider).value;
        if (userProfile?.role == UserRole.driver) {
          return '/driver';
        }
        return '/home';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/home',
        name: 'home',
        builder: (context, state) => const CustomerHomeScreen(),
      ),
      GoRoute(
        path: '/express-booking',
        name: 'express-booking',
        builder: (context, state) => const ExpressBookingScreen(),
      ),
      GoRoute(
        path: '/consignment-creation',
        name: 'consignment-creation',
        builder: (context, state) => const ConsignmentCreationScreen(),
      ),
      GoRoute(
        path: '/driver',
        name: 'driver',
        builder: (context, state) => const DriverDashboardScreen(),
      ),
      GoRoute(
        path: '/tracking/:orderId',
        name: 'tracking',
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
