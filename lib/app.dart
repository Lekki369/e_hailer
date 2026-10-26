import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'core/presentation/styles/app_colors.dart';
import 'core/presentation/styles/app_theme.dart';
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
        appScaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            content: Row(
              children: [
                const Icon(
                  Icons.notifications_active_rounded,
                  color: AppColors.secondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notification.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        notification.body,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
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
