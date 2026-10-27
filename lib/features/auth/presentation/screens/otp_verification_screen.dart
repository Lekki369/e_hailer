import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pinput/pinput.dart';

import '../../../../core/presentation/styles/app_colors.dart';
import '../../../../core/presentation/widgets/app_snackbar.dart';
import '../../../../core/routing/app_routes.dart';
import '../providers/auth_providers.dart';

class OtpVerificationScreen extends HookConsumerWidget {
  final String phoneNumber;
  final String verificationId;

  const OtpVerificationScreen({
    super.key,
    required this.phoneNumber,
    required this.verificationId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pinController = useTextEditingController();
    final currentVerificationId = useState(verificationId);
    final isLoading = useState(false);
    final errorMessage = useState<String?>(null);
    final countdown = useState(60);

    // Active 60s countdown timer
    useEffect(() {
      countdown.value = 60;
      final timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (countdown.value > 0) {
          countdown.value--;
        } else {
          t.cancel();
        }
      });
      return timer.cancel;
    }, [currentVerificationId.value]);

    Future<void> handleVerify([String? codeOverride]) async {
      final code = (codeOverride ?? pinController.text).trim();
      if (code.length != 6) {
        errorMessage.value = 'Please enter the complete 6-digit code.';
        return;
      }

      isLoading.value = true;
      errorMessage.value = null;

      final authService = ref.read(authRemoteServiceProvider);
      final result = await authService.verifyPhoneOtp(
        verificationId: currentVerificationId.value,
        smsCode: code,
        phoneNumber: phoneNumber,
      );

      isLoading.value = false;

      result.fold(
        (failure) => errorMessage.value = failure.message,
        (user) {
          // GoRouter redirect automatically routes based on role:
          // /admin for Admin, /driver for Driver, /home for Customer
        },
      );
    }

    Future<void> handleResendCode() async {
      if (countdown.value > 0) return;

      isLoading.value = true;
      errorMessage.value = null;

      final authService = ref.read(authRemoteServiceProvider);
      final result =
          await authService.sendPhoneOtp(phoneNumber: phoneNumber);

      isLoading.value = false;

      result.fold(
        (failure) => errorMessage.value = failure.message,
        (newVerificationId) {
          currentVerificationId.value = newVerificationId;
          pinController.clear();
          AppSnackBar.showSuccess(
            context,
            'A new 6-digit verification code has been dispatched.',
          );
        },
      );
    }

    final defaultPinTheme = PinTheme(
      width: 48,
      height: 54,
      textStyle: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider),
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyWith(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary, width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
    );

    final submittedPinTheme = defaultPinTheme.copyWith(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary),
      ),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Verify Phone'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.loginPath);
            }
          },
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Icon header
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.sms_outlined,
                    size: 38,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 20),

                Text(
                  'Enter 6-Digit Code',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Sent to $phoneNumber',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () {
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go(AppRoutes.phoneLoginPath);
                        }
                      },
                      child: const Text(
                        'Edit',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // Error alert
                if (errorMessage.value != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline,
                            color: AppColors.error, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            errorMessage.value!,
                            style: const TextStyle(
                              color: AppColors.error,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // 6-digit Pinput
                Center(
                  child: Pinput(
                    length: 6,
                    controller: pinController,
                    autofocus: true,
                    defaultPinTheme: defaultPinTheme,
                    focusedPinTheme: focusedPinTheme,
                    submittedPinTheme: submittedPinTheme,
                    onCompleted: (pin) => handleVerify(pin),
                  ),
                ),
                const SizedBox(height: 28),

                // Submit Button
                ElevatedButton(
                  onPressed: isLoading.value ? null : () => handleVerify(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: isLoading.value
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Verify & Sign In',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
                const SizedBox(height: 20),

                // Countdown and Resend Code
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (countdown.value > 0)
                      Text(
                        'Resend code in 00:${countdown.value.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textMuted,
                        ),
                      )
                    else
                      TextButton.icon(
                        onPressed: isLoading.value ? null : handleResendCode,
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text(
                          'Resend SMS Code',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
