import 'package:e_hailer/core/routing/app_routes.dart';
import 'package:e_hailer/core/routing/route_access.dart';
import 'package:e_hailer/features/auth/domain/user_entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a missing profile cannot enter protected routes', () {
    for (final path in [
      AppRoutes.adminDashboardPath,
      AppRoutes.driverDashboardPath,
      AppRoutes.activeDelivery('order'),
      AppRoutes.walletPath,
    ]) {
      expect(
        RouteAccess.redirect(
          location: path,
          loading: false,
          signedIn: true,
          role: null,
        ),
        AppRoutes.accountStatusPath,
      );
    }
  });
  test('public tracking exemption never includes private /tracking URLs', () {
    expect(
      RouteAccess.redirect(
        location: AppRoutes.publicTracking('code'),
        loading: true,
        signedIn: false,
        role: null,
      ),
      isNull,
    );
    expect(
      RouteAccess.redirect(
        location: AppRoutes.orderTracking('order'),
        loading: false,
        signedIn: false,
        role: null,
      ),
      AppRoutes.loginPath,
    );
  });
  test('customer cannot open a nested driver or administrative route', () {
    for (final path in [
      AppRoutes.activeDelivery('order'),
      AppRoutes.payoutManagementPath,
      AppRoutes.dispatchQueuePath,
    ]) {
      expect(
        RouteAccess.redirect(
          location: path,
          loading: false,
          signedIn: true,
          role: UserRole.customer,
        ),
        AppRoutes.customerHomePath,
      );
    }
  });
  test('support can access disputes but cannot access payouts or dispatch', () {
    expect(
      RouteAccess.redirect(
        location: AppRoutes.disputeManagementPath,
        loading: false,
        signedIn: true,
        role: UserRole.support,
      ),
      isNull,
    );
    expect(
      RouteAccess.redirect(
        location: AppRoutes.payoutManagementPath,
        loading: false,
        signedIn: true,
        role: UserRole.support,
      ),
      AppRoutes.disputeManagementPath,
    );
  });
}
