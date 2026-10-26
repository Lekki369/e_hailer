import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../../core/presentation/styles/app_colors.dart';
import '../providers/auth_providers.dart';

class LoginScreen extends HookConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final emailController = useTextEditingController();
    final passwordController = useTextEditingController();
    final isLoading = useState(false);
    final errorMessage = useState<String?>(null);

    Future<void> handleLogin() async {
      final email = emailController.text.trim();
      final password = passwordController.text.trim();
      if (email.isEmpty || password.isEmpty) {
        errorMessage.value = 'Please enter your email and password.';
        return;
      }

      isLoading.value = true;
      errorMessage.value = null;

      final authService = ref.read(authRemoteServiceProvider);
      final result = await authService.signInWithEmail(
        email: email,
        password: password,
      );

      isLoading.value = false;
      result.fold(
        (failure) => errorMessage.value = failure.message,
        (user) {
          // GoRouter redirect will automatically route based on role
        },
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo & Header
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.local_shipping_rounded,
                    size: 38,
                    color: AppColors.secondary,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Welcome to e-Hailer',
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'On-demand express dispatch & courier logistics platform',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                ),
                const SizedBox(height: 32),

                // Error alert
                if (errorMessage.value != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: AppColors.error.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      errorMessage.value!,
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Form fields
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email Address',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                ),
                const SizedBox(height: 24),

                // Submit Button
                ElevatedButton(
                  onPressed: isLoading.value ? null : handleLogin,
                  child: isLoading.value
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Sign In'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
