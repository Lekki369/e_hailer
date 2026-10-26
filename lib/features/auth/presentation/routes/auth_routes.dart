import 'package:go_router/go_router.dart';

import '../screens/login_screen.dart';

/// Screen-level route definition for Login
abstract class LoginRoute {
  static const String path = '/login';
  static const String name = 'login';

  /// GoRoute definition for LoginScreen
  static GoRoute get route => GoRoute(
        path: path,
        name: name,
        builder: (context, state) => const LoginScreen(),
      );
}

/// Feature-level route bundle for Authentication
abstract class AuthRoutes {
  static const String loginPath = LoginRoute.path;
  static const String loginName = LoginRoute.name;

  static GoRoute get loginRoute => LoginRoute.route;

  /// All GoRoutes registered by the Auth feature
  static List<GoRoute> get routes => [
        LoginRoute.route,
      ];
}
