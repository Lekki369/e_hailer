import 'package:go_router/go_router.dart';

import '../screens/admin_dashboard_screen.dart';
import '../screens/admin_map_overview_screen.dart';
import '../screens/dispatch_queue_screen.dart';
import '../screens/driver_management_screen.dart';

/// Centralized route definitions for Admin & Dispatcher operations.
class AdminRoutes {
  static const String adminDashboardName = 'admin-dashboard';
  static const String adminDashboardPath = '/admin';

  static const String dispatchQueueName = 'dispatch-queue';
  static const String dispatchQueuePath = '/admin/dispatch-queue';

  static const String driverManagementName = 'driver-management';
  static const String driverManagementPath = '/admin/driver-management';

  static const String adminMapOverviewName = 'admin-map-overview';
  static const String adminMapOverviewPath = '/admin/map-overview';

  static final List<RouteBase> routes = [
    GoRoute(
      name: adminDashboardName,
      path: adminDashboardPath,
      builder: (context, state) => const AdminDashboardScreen(),
    ),
    GoRoute(
      name: dispatchQueueName,
      path: dispatchQueuePath,
      builder: (context, state) => const DispatchQueueScreen(),
    ),
    GoRoute(
      name: driverManagementName,
      path: driverManagementPath,
      builder: (context, state) => const DriverManagementScreen(),
    ),
    GoRoute(
      name: adminMapOverviewName,
      path: adminMapOverviewPath,
      builder: (context, state) => const AdminMapOverviewScreen(),
    ),
  ];
}
