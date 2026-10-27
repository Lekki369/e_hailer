import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'core/presentation/styles/app_theme.dart';
import 'core/presentation/widgets/app_snackbar.dart';
import 'core/routing/app_router.dart';
import 'features/auth/presentation/providers/auth_providers.dart';
import 'features/notification/presentation/providers/notification_providers.dart';

final GlobalKey<ScaffoldMessengerState> appScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

class EHailerApp extends ConsumerWidget {
  const EHailerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    // Auto-sync FCM Token when user profile loads
    ref.listen(currentUserProfileProvider, (_, next) {
      final user = next.value;
      if (user != null) {
        ref.read(notificationRemoteServiceProvider).initialize(uid: user.uid);
      }
    });

    // Display floating in-app notification banner on incoming push
    ref.listen(foregroundNotificationStreamProvider, (_, next) {
      final notification = next.value;
      if (notification != null) {
        AppSnackBar.showGlobal(
          title: notification.title,
          message: notification.body,
          type: SnackBarType.info,
        );
      }
    });

    return ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MaterialApp.router(
          title: 'e-Hailer Logistics',
          scaffoldMessengerKey: appScaffoldMessengerKey,
          theme: AppTheme.lightTheme,
          debugShowCheckedModeBanner: false,
          routerConfig: router,
        );
      },
    );
  }
}
