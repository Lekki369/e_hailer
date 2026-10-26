import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../features/auth/domain/user_entity.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';
import 'app_routes.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authStateAsync = ref.watch(authStateProvider);
  final userProfileAsync = ref.watch(currentUserProfileProvider);

  return GoRouter(
    initialLocation: AppRoutes.customerHomePath,
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final isLoggedIn = authStateAsync.value != null;
      final isAuthFlow = state.matchedLocation == AppRoutes.loginPath ||
          state.matchedLocation == AppRoutes.registerPath ||
          state.matchedLocation == AppRoutes.forgotPasswordPath ||
          state.matchedLocation == AppRoutes.phoneLoginPath ||
          state.matchedLocation == AppRoutes.verifyOtpPath;
      final isPublicTracking = state.matchedLocation.startsWith('/track');
      final user = userProfileAsync.value;

      if (!isLoggedIn) {
        if (isAuthFlow || isPublicTracking) {
          return null;
        }
        return AppRoutes.loginPath;
      }

      if (isAuthFlow) {
        if (user?.role == UserRole.admin) {
          return AppRoutes.adminDashboardPath;
        }
        if (user?.role == UserRole.driver) {
          return AppRoutes.driverDashboardPath;
        }
        return AppRoutes.customerHomePath;
      }

      // Root landing page redirection based on user role
      if (state.matchedLocation == AppRoutes.customerHomePath) {
        if (user?.role == UserRole.admin) {
          return AppRoutes.adminDashboardPath;
        }
        if (user?.role == UserRole.driver) {
          return AppRoutes.driverDashboardPath;
        }
      }

      // Role-based protection for Admin routes
      final isAdminRoute = state.matchedLocation.startsWith('/admin');
      if (isAdminRoute && user != null && user.role != UserRole.admin) {
        return user.role == UserRole.driver
            ? AppRoutes.driverDashboardPath
            : AppRoutes.customerHomePath;
      }

      // Role-based protection for Driver fleet terminal
      final isDriverRoute =
          state.matchedLocation == AppRoutes.driverDashboardPath;
      if (isDriverRoute && user != null && user.role != UserRole.driver) {
        return user.role == UserRole.admin
            ? AppRoutes.adminDashboardPath
            : AppRoutes.customerHomePath;
      }

      return null;
    },
    routes: [
      ...AuthRoutes.routes,
      ...DeliveryRoutes.routes,
      ...WalletRoutes.routes,
      ...AdminRoutes.routes,
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
