import 'package:go_router/go_router.dart';

import '../screens/login_screen.dart';
import '../screens/profile_screen.dart';

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

/// Screen-level route definition for User Profile & Settings
abstract class ProfileRoute {
  static const String path = '/profile';
  static const String name = 'profile';

  /// GoRoute definition for ProfileScreen
  static GoRoute get route => GoRoute(
        path: path,
        name: name,
        builder: (context, state) => const ProfileScreen(),
      );
}

/// Feature-level route bundle for Authentication & Profiles
abstract class AuthRoutes {
  static const String loginPath = LoginRoute.path;
  static const String loginName = LoginRoute.name;

  static const String profilePath = ProfileRoute.path;
  static const String profileName = ProfileRoute.name;

  static GoRoute get loginRoute => LoginRoute.route;
  static GoRoute get profileRoute => ProfileRoute.route;

  /// All GoRoutes registered by the Auth feature
  static List<GoRoute> get routes => [
        LoginRoute.route,
        ProfileRoute.route,
      ];
}
