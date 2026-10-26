import 'package:go_router/go_router.dart';

import '../screens/forgot_password_screen.dart';
import '../screens/login_screen.dart';
import '../screens/otp_verification_screen.dart';
import '../screens/phone_login_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/register_screen.dart';

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

/// Screen-level route definition for Phone Login
abstract class PhoneLoginRoute {
  static const String path = '/phone-login';
  static const String name = 'phone-login';

  /// GoRoute definition for PhoneLoginScreen
  static GoRoute get route => GoRoute(
        path: path,
        name: name,
        builder: (context, state) => const PhoneLoginScreen(),
      );
}

/// Screen-level route definition for OTP Verification
abstract class OtpVerificationRoute {
  static const String path = '/verify-otp';
  static const String name = 'verify-otp';

  /// GoRoute definition for OtpVerificationScreen
  static GoRoute get route => GoRoute(
        path: path,
        name: name,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          final phoneNumber = extra['phoneNumber'] as String? ?? '';
          final verificationId = extra['verificationId'] as String? ?? '';
          return OtpVerificationScreen(
            phoneNumber: phoneNumber,
            verificationId: verificationId,
          );
        },
      );
}

/// Screen-level route definition for User Registration / Sign Up
abstract class RegisterRoute {
  static const String path = '/register';
  static const String name = 'register';

  /// GoRoute definition for RegisterScreen
  static GoRoute get route => GoRoute(
        path: path,
        name: name,
        builder: (context, state) => const RegisterScreen(),
      );
}

/// Screen-level route definition for Password Reset
abstract class ForgotPasswordRoute {
  static const String path = '/forgot-password';
  static const String name = 'forgot-password';

  /// GoRoute definition for ForgotPasswordScreen
  static GoRoute get route => GoRoute(
        path: path,
        name: name,
        builder: (context, state) => const ForgotPasswordScreen(),
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

  static const String phoneLoginPath = PhoneLoginRoute.path;
  static const String phoneLoginName = PhoneLoginRoute.name;

  static const String verifyOtpPath = OtpVerificationRoute.path;
  static const String verifyOtpName = OtpVerificationRoute.name;

  static const String registerPath = RegisterRoute.path;
  static const String registerName = RegisterRoute.name;

  static const String forgotPasswordPath = ForgotPasswordRoute.path;
  static const String forgotPasswordName = ForgotPasswordRoute.name;

  static const String profilePath = ProfileRoute.path;
  static const String profileName = ProfileRoute.name;

  static GoRoute get loginRoute => LoginRoute.route;
  static GoRoute get phoneLoginRoute => PhoneLoginRoute.route;
  static GoRoute get verifyOtpRoute => OtpVerificationRoute.route;
  static GoRoute get registerRoute => RegisterRoute.route;
  static GoRoute get forgotPasswordRoute => ForgotPasswordRoute.route;
  static GoRoute get profileRoute => ProfileRoute.route;

  /// All GoRoutes registered by the Auth feature
  static List<GoRoute> get routes => [
        LoginRoute.route,
        PhoneLoginRoute.route,
        OtpVerificationRoute.route,
        RegisterRoute.route,
        ForgotPasswordRoute.route,
        ProfileRoute.route,
      ];
}
