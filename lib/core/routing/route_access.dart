import '../../features/auth/domain/user_entity.dart';
import 'app_routes.dart';

abstract final class RouteAccess {
  static bool within(String location, String root) =>
      location == root || location.startsWith('$root/');
  static String home(UserRole role) => switch (role) {
    UserRole.admin => AppRoutes.adminDashboardPath,
    UserRole.support => AppRoutes.disputeManagementPath,
    UserRole.driver => AppRoutes.driverDashboardPath,
    UserRole.customer => AppRoutes.customerHomePath,
  };
  static String? redirect({
    required String location,
    required bool loading,
    required bool signedIn,
    required UserRole? role,
  }) {
    if (within(location, AppRoutes.publicTrackingPath)) return null;
    if (loading) {
      return location == AppRoutes.accountStatusPath
          ? null
          : AppRoutes.accountStatusPath;
    }
    final authFlow = {
      AppRoutes.loginPath,
      AppRoutes.registerPath,
      AppRoutes.phoneLoginPath,
      AppRoutes.verifyOtpPath,
      AppRoutes.forgotPasswordPath,
    }.contains(location);
    if (!signedIn) return authFlow ? null : AppRoutes.loginPath;
    if (role == null) {
      return location == AppRoutes.accountStatusPath
          ? null
          : AppRoutes.accountStatusPath;
    }
    if (authFlow || location == AppRoutes.accountStatusPath) return home(role);
    if (within(location, AppRoutes.adminDashboardPath) &&
        role != UserRole.admin) {
      if (role == UserRole.support &&
          location == AppRoutes.disputeManagementPath) {
        return null;
      }
      return home(role);
    }
    if (within(location, AppRoutes.driverDashboardPath) &&
        role != UserRole.driver) {
      return home(role);
    }
    final customerOnly = {
      AppRoutes.customerHomePath,
      AppRoutes.expressBookingPath,
      AppRoutes.consignmentCreationPath,
    };
    if (customerOnly.contains(location) && role != UserRole.customer) {
      return home(role);
    }
    return null;
  }
}
