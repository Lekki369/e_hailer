/// Centralized Route Definitions and Exports for e-Hailer
///
/// Features define their own [GoRoute] configurations and screen-level route classes
/// ([LoginRoute], [CustomerHomeRoute], [ExpressBookingRoute], etc.).
/// [AppRoutes] provides universal shortcuts and paths for the router and navigation.
library;

import '../../features/auth/presentation/routes/auth_routes.dart';
import '../../features/delivery/presentation/routes/delivery_routes.dart';
import '../../features/wallet/presentation/routes/wallet_routes.dart';

export '../../features/auth/presentation/routes/auth_routes.dart';
export '../../features/delivery/presentation/routes/delivery_routes.dart';
export '../../features/wallet/presentation/routes/wallet_routes.dart';

/// Universal Route Registry for GoRouter and App Navigation
abstract class AppRoutes {
  // Authentication & Onboarding
  static const String loginName = AuthRoutes.loginName;
  static const String loginPath = AuthRoutes.loginPath;

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

  // Digital Wallet & Ledger
  static const String walletName = WalletRoutes.walletName;
  static const String walletPath = WalletRoutes.walletPath;
}
