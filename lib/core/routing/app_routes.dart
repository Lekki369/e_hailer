/// Centralized Route Definitions and Exports for e-Hailer
///
/// Features define their own [GoRoute] configurations and screen-level route classes
/// ([LoginRoute], [CustomerHomeRoute], [ExpressBookingRoute], etc.).
/// [AppRoutes] provides universal shortcuts and paths for the router and navigation.
library;

import '../../features/admin/presentation/routes/admin_routes.dart';
import '../../features/auth/presentation/routes/auth_routes.dart';
import '../../features/delivery/presentation/routes/delivery_routes.dart';
import '../../features/wallet/presentation/routes/wallet_routes.dart';

export '../../features/admin/presentation/routes/admin_routes.dart';
export '../../features/auth/presentation/routes/auth_routes.dart';
export '../../features/delivery/presentation/routes/delivery_routes.dart';
export '../../features/wallet/presentation/routes/wallet_routes.dart';

/// Universal Route Registry for GoRouter and App Navigation
abstract class AppRoutes {
  // Authentication & Onboarding
  static const String loginName = AuthRoutes.loginName;
  static const String loginPath = AuthRoutes.loginPath;

  static const String registerName = AuthRoutes.registerName;
  static const String registerPath = AuthRoutes.registerPath;

  static const String forgotPasswordName = AuthRoutes.forgotPasswordName;
  static const String forgotPasswordPath = AuthRoutes.forgotPasswordPath;

  static const String profileName = AuthRoutes.profileName;
  static const String profilePath = AuthRoutes.profilePath;

  // Customer & Driver Dashboards
  static const String customerHomeName = DeliveryRoutes.customerHomeName;
  static const String customerHomePath = DeliveryRoutes.customerHomePath;

  static const String driverDashboardName = DeliveryRoutes.driverDashboardName;
  static const String driverDashboardPath = DeliveryRoutes.driverDashboardPath;

  static const String activeDeliveryName = DeliveryRoutes.activeDeliveryName;
  static const String activeDeliveryPath = DeliveryRoutes.activeDeliveryPath;
  static String activeDelivery(String orderId) =>
      DeliveryRoutes.activeDelivery(orderId);

  // Admin & Dispatcher Operations
  static const String adminDashboardName = AdminRoutes.adminDashboardName;
  static const String adminDashboardPath = AdminRoutes.adminDashboardPath;

  static const String dispatchQueueName = AdminRoutes.dispatchQueueName;
  static const String dispatchQueuePath = AdminRoutes.dispatchQueuePath;

  static const String driverManagementName = AdminRoutes.driverManagementName;
  static const String driverManagementPath = AdminRoutes.driverManagementPath;

  static const String adminMapOverviewName = AdminRoutes.adminMapOverviewName;
  static const String adminMapOverviewPath = AdminRoutes.adminMapOverviewPath;

  static const String disputeManagementName = AdminRoutes.disputeManagementName;
  static const String disputeManagementPath = AdminRoutes.disputeManagementPath;

  static const String analyticsDashboardName = AdminRoutes.analyticsDashboardName;
  static const String analyticsDashboardPath = AdminRoutes.analyticsDashboardPath;

  // Order Booking & Dispatch
  static const String expressBookingName = DeliveryRoutes.expressBookingName;
  static const String expressBookingPath = DeliveryRoutes.expressBookingPath;

  static const String consignmentCreationName =
      DeliveryRoutes.consignmentCreationName;
  static const String consignmentCreationPath =
      DeliveryRoutes.consignmentCreationPath;

  // Tracking & Lifecycle
  static const String orderTrackingName = DeliveryRoutes.orderTrackingName;
  static const String orderTrackingPath = DeliveryRoutes.orderTrackingPath;

  /// Parameterized tracking path helper
  static String orderTracking(String orderId) =>
      DeliveryRoutes.orderTracking(orderId);

  static const String publicTrackingName = DeliveryRoutes.publicTrackingName;
  static const String publicTrackingPath = DeliveryRoutes.publicTrackingPath;

  /// Parameterized public tracking path helper
  static String publicTracking(String trackingNumber) =>
      DeliveryRoutes.publicTracking(trackingNumber);

  // Digital Wallet & Ledger
  static const String walletName = WalletRoutes.walletName;
  static const String walletPath = WalletRoutes.walletPath;

  static const String payoutManagementName =
      WalletRoutes.payoutManagementName;
  static const String payoutManagementPath =
      WalletRoutes.payoutManagementPath;
}
