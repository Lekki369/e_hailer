import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../core/presentation/styles/app_colors.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../delivery/domain/value_objects/delivery_type.dart';
import '../../domain/user_entity.dart';
import '../providers/auth_providers.dart';

class RegisterScreen extends HookConsumerWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nameController = useTextEditingController();
    final emailController = useTextEditingController();
    final phoneController = useTextEditingController();
    final passwordController = useTextEditingController();
    final confirmPasswordController = useTextEditingController();

    // Driver specific fields
    final plateController = useTextEditingController();
    final modelController = useTextEditingController();
    final selectedVehicle = useState<VehicleType>(VehicleType.bike);

    final selectedRole = useState<UserRole>(UserRole.customer);
    final obscurePassword = useState(true);
    final obscureConfirm = useState(true);
    final isLoading = useState(false);
    final errorMessage = useState<String?>(null);

    final isDriver = selectedRole.value == UserRole.driver;

    Future<void> handleRegister() async {
      final name = nameController.text.trim();
      final email = emailController.text.trim();
      final phone = phoneController.text.trim();
      final password = passwordController.text.trim();
      final confirmPassword = confirmPasswordController.text.trim();

      if (name.isEmpty || email.isEmpty || phone.isEmpty || password.isEmpty) {
        errorMessage.value = 'Please fill in all required profile fields.';
        return;
      }

      if (!email.contains('@') || !email.contains('.')) {
        errorMessage.value = 'Please enter a valid email address.';
        return;
      }

      if (password.length < 6) {
        errorMessage.value = 'Password must be at least 6 characters.';
        return;
      }

      if (password != confirmPassword) {
        errorMessage.value = 'Passwords do not match.';
        return;
      }

      if (isDriver) {
        if (plateController.text.trim().isEmpty ||
            modelController.text.trim().isEmpty) {
          errorMessage.value =
              'Please enter your vehicle plate number and model.';
          return;
        }
      }

      isLoading.value = true;
      errorMessage.value = null;

      final authService = ref.read(authRemoteServiceProvider);
      final result = await authService.signUpWithEmail(
        email: email,
        password: password,
        fullName: name,
        phone: phone,
        role: selectedRole.value,
        vehicleType: isDriver ? selectedVehicle.value : null,
        vehiclePlateNumber: isDriver ? plateController.text.trim() : null,
        vehicleModel: isDriver ? modelController.text.trim() : null,
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

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Create Account'),
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Role Selection Segment
              const Text(
                'I want to register as:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: _buildRoleCard(
                      title: 'Customer',
                      subtitle: 'Send & Track Cargo',
                      icon: Icons.person_outline_rounded,
                      isSelected: selectedRole.value == UserRole.customer,
                      onTap: () => selectedRole.value = UserRole.customer,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildRoleCard(
                      title: 'Courier / Driver',
                      subtitle: 'Earn Delivering',
                      icon: Icons.two_wheeler_rounded,
                      isSelected: selectedRole.value == UserRole.driver,
                      onTap: () => selectedRole.value = UserRole.driver,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 2. Error message banner
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
                const SizedBox(height: 16),
              ],

              // 3. User Details Fields
              TextField(
                controller: nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
              ),
              const SizedBox(height: 14),

              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email Address',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 14),

              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone Number (e.g. +234...)',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: 14),

              TextField(
                controller: passwordController,
                obscureText: obscurePassword.value,
                decoration: InputDecoration(
                  labelText: 'Password (min. 6 characters)',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscurePassword.value
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () =>
                        obscurePassword.value = !obscurePassword.value,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              TextField(
                controller: confirmPasswordController,
                obscureText: obscureConfirm.value,
                decoration: InputDecoration(
                  labelText: 'Confirm Password',
                  prefixIcon: const Icon(Icons.lock_reset_rounded),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscureConfirm.value
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () =>
                        obscureConfirm.value = !obscureConfirm.value,
                  ),
                ),
              ),

              // 4. Driver Specific Fields
              if (isDriver) ...[
                const SizedBox(height: 24),
                Text(
                  'Driver Fleet Vehicle Setup',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                ),
                const SizedBox(height: 10),

                // Vehicle Category Selector
                Row(
                  children: VehicleType.values.map((v) {
                    final isSelected = selectedVehicle.value == v;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => selectedVehicle.value = v,
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.secondary
                                : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.secondary
                                  : AppColors.divider,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                v == VehicleType.bike
                                    ? Icons.two_wheeler
                                    : v == VehicleType.car
                                        ? Icons.directions_car
                                        : Icons.local_shipping,
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.textPrimary,
                                size: 20,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                v.name.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected
                                      ? Colors.white
                                      : AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                '${v.rateMultiplier}x',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: isSelected
                                      ? Colors.white70
                                      : AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),

                TextField(
                  controller: plateController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Vehicle Plate Number (e.g. ABC-123XY)',
                    prefixIcon: Icon(Icons.confirmation_number_outlined),
                  ),
                ),
                const SizedBox(height: 14),

                TextField(
                  controller: modelController,
                  decoration: const InputDecoration(
                    labelText: 'Vehicle Make & Model (e.g. Bajaj Boxer 150)',
                    prefixIcon: Icon(Icons.directions_car_outlined),
                  ),
                ),
              ],

              const SizedBox(height: 28),

              // 5. Submit Registration
              ElevatedButton(
                onPressed: isLoading.value ? null : handleRegister,
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
                    : Text(
                        isDriver
                            ? 'Register as Fleet Driver'
                            : 'Create Customer Account',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
              const SizedBox(height: 18),

              // Divider OR
              const Row(
                children: [
                  Expanded(child: Divider(color: AppColors.divider)),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'OR',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                  Expanded(child: Divider(color: AppColors.divider)),
                ],
              ),
              const SizedBox(height: 14),

              // Passwordless Phone Sign Up
              OutlinedButton.icon(
                icon: const Icon(Icons.phone_iphone_rounded,
                    color: AppColors.primary),
                label: const Text('Continue with Phone Number'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: AppColors.divider),
                ),
                onPressed: () => context.push(AppRoutes.phoneLoginPath),
              ),
              const SizedBox(height: 20),

              // 6. Sign In Link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Already have an account?',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  TextButton(
                    onPressed: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go(AppRoutes.loginPath);
                      }
                    },
                    child: const Text(
                      'Sign In',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.divider,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 26,
              color: isSelected ? AppColors.secondary : AppColors.textPrimary,
            ),
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                color: isSelected ? Colors.white70 : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
