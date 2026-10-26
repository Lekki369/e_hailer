/// Centralized Route Definitions for e-Hailer
///
/// Organized by feature modules with unified access via [AppRoutes].
library;

/// Routes for Authentication and User Onboarding
abstract class AuthRoutes {
  static const String loginName = 'login';
  static const String loginPath = '/login';
}

/// Routes for Logistics, Courier Hailing, and Consignment Management
abstract class DeliveryRoutes {
  static const String customerHomeName = 'home';
  static const String customerHomePath = '/home';

  static const String driverDashboardName = 'driver';
  static const String driverDashboardPath = '/driver';

  static const String expressBookingName = 'express-booking';
  static const String expressBookingPath = '/express-booking';

  static const String consignmentCreationName = 'consignment-creation';
  static const String consignmentCreationPath = '/consignment-creation';

  static const String orderTrackingName = 'tracking';
  static const String orderTrackingPath = '/tracking/:orderId';

  /// Helper to generate dynamic parameterized tracking path
  static String orderTracking(String orderId) => '/tracking/$orderId';
}

/// Universal Route Registry for GoRouter and App Navigation
abstract class AppRoutes {
  // Authentication & Onboarding
  static const String loginName = AuthRoutes.loginName;
  static const String loginPath = AuthRoutes.loginPath;

  // Customer & Driver Dashboards
  static const String customerHomeName = DeliveryRoutes.customerHomeName;
  static const String customerHomePath = DeliveryRoutes.customerHomePath;

  static const String driverDashboardName = DeliveryRoutes.driverDashboardName;
  static const String driverDashboardPath = DeliveryRoutes.driverDashboardPath;

  // Order Booking & Dispatch
  static const String expressBookingName = DeliveryRoutes.expressBookingName;
  static const String expressBookingPath = DeliveryRoutes.expressBookingPath;

  static const String consignmentCreationName = DeliveryRoutes.consignmentCreationName;
  static const String consignmentCreationPath = DeliveryRoutes.consignmentCreationPath;

  // Tracking & Lifecycle
  static const String orderTrackingName = DeliveryRoutes.orderTrackingName;
  static const String orderTrackingPath = DeliveryRoutes.orderTrackingPath;

  /// Parameterized tracking path helper
  static String orderTracking(String orderId) => DeliveryRoutes.orderTracking(orderId);
}
