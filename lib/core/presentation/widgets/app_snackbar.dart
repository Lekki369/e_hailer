import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app.dart';
import '../styles/app_colors.dart';

/// Semantic types of snackbar messages
enum SnackBarType { success, error, warning, info }

/// Global standardized SnackBar utility and widget for e-Hailer
class AppSnackBar {
  AppSnackBar._();

  /// Primary helper to show a styled SnackBar with BuildContext
  static void show(
    BuildContext context, {
    required String message,
    String? title,
    SnackBarType type = SnackBarType.info,
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      buildSnackBar(
        message: message,
        title: title,
        type: type,
        duration: duration,
        action: action,
      ),
    );
  }

  /// Convenience helper for success messages
  static void showSuccess(
    BuildContext context,
    String message, {
    String? title,
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
  }) =>
      show(
        context,
        message: message,
        title: title,
        type: SnackBarType.success,
        duration: duration,
        action: action,
      );

  /// Convenience helper for error messages
  static void showError(
    BuildContext context,
    String message, {
    String? title,
    Duration duration = const Duration(seconds: 4),
    SnackBarAction? action,
  }) =>
      show(
        context,
        message: message,
        title: title,
        type: SnackBarType.error,
        duration: duration,
        action: action,
      );

  /// Convenience helper for warning messages
  static void showWarning(
    BuildContext context,
    String message, {
    String? title,
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
  }) =>
      show(
        context,
        message: message,
        title: title,
        type: SnackBarType.warning,
        duration: duration,
        action: action,
      );

  /// Convenience helper for informational messages
  static void showInfo(
    BuildContext context,
    String message, {
    String? title,
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
  }) =>
      show(
        context,
        message: message,
        title: title,
        type: SnackBarType.info,
        duration: duration,
        action: action,
      );

  /// Global helper when BuildContext is unavailable or inside async providers
  static void showGlobal({
    required String message,
    String? title,
    SnackBarType type = SnackBarType.info,
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
  }) {
    final state = appScaffoldMessengerKey.currentState;
    if (state == null) return;
    state.hideCurrentSnackBar();
    state.showSnackBar(
      buildSnackBar(
        message: message,
        title: title,
        type: type,
        duration: duration,
        action: action,
      ),
    );
  }

  static void showGlobalSuccess(
    String message, {
    String? title,
    Duration duration = const Duration(seconds: 3),
  }) =>
      showGlobal(
        message: message,
        title: title,
        type: SnackBarType.success,
        duration: duration,
      );

  static void showGlobalError(
    String message, {
    String? title,
    Duration duration = const Duration(seconds: 4),
  }) =>
      showGlobal(
        message: message,
        title: title,
        type: SnackBarType.error,
        duration: duration,
      );

  /// Builds the standardized SnackBar configuration
  static SnackBar buildSnackBar({
    required String message,
    String? title,
    required SnackBarType type,
    required Duration duration,
    SnackBarAction? action,
  }) {
    final (Color bgColor, IconData iconData, Color iconColor) = switch (type) {
      SnackBarType.success => (
          const Color(0xFF064E3B), // Deep emerald
          Icons.check_circle_rounded,
          AppColors.success,
        ),
      SnackBarType.error => (
          const Color(0xFF450A0A), // Deep crimson
          Icons.error_outline_rounded,
          AppColors.error,
        ),
      SnackBarType.warning => (
          const Color(0xFF78350F), // Deep amber
          Icons.warning_amber_rounded,
          AppColors.warning,
        ),
      SnackBarType.info => (
          AppColors.primary, // Deep slate
          Icons.info_outline_rounded,
          AppColors.info,
        ),
    };

    return SnackBar(
      backgroundColor: bgColor,
      behavior: SnackBarBehavior.floating,
      duration: duration,
      margin: EdgeInsets.all(16.r),
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14.r),
        side: BorderSide(
          color: iconColor.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      action: action,
      content: AppSnackBarContent(
        message: message,
        title: title,
        iconData: iconData,
        iconColor: iconColor,
      ),
    );
  }
}

/// Standalone visual layout for the SnackBar message with icon badge
class AppSnackBarContent extends StatelessWidget {
  final String message;
  final String? title;
  final IconData iconData;
  final Color iconColor;

  const AppSnackBarContent({
    super.key,
    required this.message,
    this.title,
    required this.iconData,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment:
          title != null ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Container(
          padding: EdgeInsets.all(6.r),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(
            iconData,
            size: 20.sp,
            color: iconColor,
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (title != null && title!.isNotEmpty) ...[
                Text(
                  title!,
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 2.h),
              ],
              Text(
                message,
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.95),
                  height: 1.3,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
