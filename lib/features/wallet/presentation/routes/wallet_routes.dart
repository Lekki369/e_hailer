import 'package:go_router/go_router.dart';
import '../screens/payout_management_screen.dart';
import '../screens/wallet_screen.dart';

/// Screen-level route definition for Digital Wallet
abstract class WalletRoute {
  static const String path = '/wallet';
  static const String name = 'wallet';

  static GoRoute get route => GoRoute(
        path: path,
        name: name,
        builder: (context, state) => const WalletScreen(),
      );
}

/// Screen-level route definition for Admin Payout Management
abstract class PayoutManagementRoute {
  static const String path = '/admin/payouts';
  static const String name = 'admin-payouts';

  static GoRoute get route => GoRoute(
        path: path,
        name: name,
        builder: (context, state) => const PayoutManagementScreen(),
      );
}

/// Feature-level route bundle for Digital Wallet & Ledger
abstract class WalletRoutes {
  static const String walletPath = WalletRoute.path;
  static const String walletName = WalletRoute.name;

  static const String payoutManagementPath = PayoutManagementRoute.path;
  static const String payoutManagementName = PayoutManagementRoute.name;

  static GoRoute get walletRoute => WalletRoute.route;
  static GoRoute get payoutManagementRoute => PayoutManagementRoute.route;

  /// All GoRoutes registered by the Wallet feature
  static List<GoRoute> get routes => [
        WalletRoute.route,
        PayoutManagementRoute.route,
      ];
}
