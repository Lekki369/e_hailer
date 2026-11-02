import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/auth/presentation/screens/account_status_screen.dart';
import 'app_routes.dart';
import 'route_access.dart';

/// A stable router refreshes on session changes without discarding the back stack.
final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(authStateProvider, (_, _) => refresh.value++);
  ref.listen(currentUserProfileProvider, (_, _) => refresh.value++);
  String? pendingLocation;
  final router = GoRouter(
    initialLocation: AppRoutes.customerHomePath,
    debugLogDiagnostics: false,
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authStateProvider);
      final profile = ref.read(currentUserProfileProvider);
      final location = state.uri.path;
      final loading =
          auth.isLoading || (auth.value != null && profile.isLoading);
      final target = RouteAccess.redirect(
        location: location,
        loading: loading,
        signedIn: auth.value != null,
        role: profile.value?.role,
      );
      if (target == AppRoutes.accountStatusPath ||
          target == AppRoutes.loginPath) {
        if (!{
          AppRoutes.accountStatusPath,
          AppRoutes.loginPath,
        }.contains(location)) {
          pendingLocation = state.uri.toString();
        }
      }
      if (target != null &&
          profile.value != null &&
          {
            AppRoutes.accountStatusPath,
            AppRoutes.loginPath,
          }.contains(location)) {
        final pending = pendingLocation;
        pendingLocation = null;
        if (pending != null &&
            RouteAccess.redirect(
                  location: Uri.parse(pending).path,
                  loading: false,
                  signedIn: true,
                  role: profile.value!.role,
                ) ==
                null) {
          return pending;
        }
      }
      return target;
    },
    routes: [
      GoRoute(
        path: AppRoutes.accountStatusPath,
        builder: (_, _) => const AccountStatusScreen(),
      ),
      ...AuthRoutes.routes,
      ...DeliveryRoutes.routes,
      ...WalletRoutes.routes,
      ...AdminRoutes.routes,
    ],
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});
