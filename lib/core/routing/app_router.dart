import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../features/auth/domain/user_entity.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';
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
      ...AuthRoutes.routes,
      ...DeliveryRoutes.routes,
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
