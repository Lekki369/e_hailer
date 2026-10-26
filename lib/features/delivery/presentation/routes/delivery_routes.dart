import 'package:go_router/go_router.dart';

import '../screens/consignment_creation_screen.dart';
import '../screens/customer_home_screen.dart';
import '../screens/driver_dashboard_screen.dart';
import '../screens/express_booking_screen.dart';
import '../screens/order_tracking_screen.dart';

/// Screen-level route definition for Customer Home
abstract class CustomerHomeRoute {
  static const String path = '/home';
  static const String name = 'home';

  static GoRoute get route => GoRoute(
        path: path,
        name: name,
        builder: (context, state) => const CustomerHomeScreen(),
      );
}

/// Screen-level route definition for Driver Dashboard
abstract class DriverDashboardRoute {
  static const String path = '/driver';
  static const String name = 'driver';

  static GoRoute get route => GoRoute(
        path: path,
        name: name,
        builder: (context, state) => const DriverDashboardScreen(),
      );
}

/// Screen-level route definition for Express Booking
abstract class ExpressBookingRoute {
  static const String path = '/express-booking';
  static const String name = 'express-booking';

  static GoRoute get route => GoRoute(
        path: path,
        name: name,
        builder: (context, state) => const ExpressBookingScreen(),
      );
}

/// Screen-level route definition for Consignment Creation
abstract class ConsignmentCreationRoute {
  static const String path = '/consignment-creation';
  static const String name = 'consignment-creation';

  static GoRoute get route => GoRoute(
        path: path,
        name: name,
        builder: (context, state) => const ConsignmentCreationScreen(),
      );
}

/// Screen-level route definition for Order Tracking
abstract class OrderTrackingRoute {
  static const String path = '/tracking/:orderId';
  static const String name = 'tracking';

  /// Helper to build parameterized path
  static String pathWithId(String orderId) => '/tracking/$orderId';

  static GoRoute get route => GoRoute(
        path: path,
        name: name,
        builder: (context, state) {
          final orderId = state.pathParameters['orderId'] ?? '';
          return OrderTrackingScreen(orderId: orderId);
        },
      );
}

/// Feature-level route bundle for Deliveries & Logistics
abstract class DeliveryRoutes {
  // Path & Name References
  static const String customerHomePath = CustomerHomeRoute.path;
  static const String customerHomeName = CustomerHomeRoute.name;

  static const String driverDashboardPath = DriverDashboardRoute.path;
  static const String driverDashboardName = DriverDashboardRoute.name;

  static const String expressBookingPath = ExpressBookingRoute.path;
  static const String expressBookingName = ExpressBookingRoute.name;

  static const String consignmentCreationPath = ConsignmentCreationRoute.path;
  static const String consignmentCreationName = ConsignmentCreationRoute.name;

  static const String orderTrackingPath = OrderTrackingRoute.path;
  static const String orderTrackingName = OrderTrackingRoute.name;

  static String orderTracking(String orderId) =>
      OrderTrackingRoute.pathWithId(orderId);

  // Screen GoRoutes
  static GoRoute get customerHomeRoute => CustomerHomeRoute.route;
  static GoRoute get driverDashboardRoute => DriverDashboardRoute.route;
  static GoRoute get expressBookingRoute => ExpressBookingRoute.route;
  static GoRoute get consignmentCreationRoute => ConsignmentCreationRoute.route;
  static GoRoute get orderTrackingRoute => OrderTrackingRoute.route;

  /// All GoRoutes registered by the Delivery feature
  static List<GoRoute> get routes => [
        CustomerHomeRoute.route,
        DriverDashboardRoute.route,
        ExpressBookingRoute.route,
        ConsignmentCreationRoute.route,
        OrderTrackingRoute.route,
      ];
}
