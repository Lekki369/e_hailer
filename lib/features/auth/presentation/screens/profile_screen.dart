import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../core/presentation/styles/app_colors.dart';
import '../../../../core/presentation/widgets/app_snackbar.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../delivery/domain/value_objects/delivery_type.dart';
import '../../domain/user_entity.dart';
import '../providers/auth_providers.dart';

class ProfileScreen extends HookConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfileAsync = ref.watch(currentUserProfileProvider);
    final user = userProfileAsync.value;

    final isDriver = user?.role == UserRole.driver;
    final isAdmin = user?.role == UserRole.admin;

    final nameController = useTextEditingController(text: user?.fullName ?? '');
    final phoneController = useTextEditingController(text: user?.phone ?? '');
    final plateController =
        useTextEditingController(text: user?.vehiclePlateNumber ?? '');
    final modelController =
        useTextEditingController(text: user?.vehicleModel ?? '');

    final selectedVehicle = useState<VehicleType>(
      user?.vehicleType ?? VehicleType.bike,
    );
    final isSaving = useState(false);

    useEffect(() {
      if (user != null) {
        nameController.text = user.fullName;
        phoneController.text = user.phone;
        plateController.text = user.vehiclePlateNumber ?? '';
        modelController.text = user.vehicleModel ?? '';
        selectedVehicle.value = user.vehicleType ?? VehicleType.bike;
      }
      return null;
    }, [user?.uid]);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile & Settings'),
      ),
      body: user == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Profile Avatar & Role Header
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor:
                              AppColors.primary.withValues(alpha: 0.1),
                          child: Icon(
                            isAdmin
                                ? Icons.admin_panel_settings_rounded
                                : isDriver
                                    ? Icons.two_wheeler_rounded
                                    : Icons.person_rounded,
                            size: 36,
                            color: isAdmin ? Colors.purple : AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.fullName,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                user.email,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isAdmin
                                      ? Colors.purple.shade50
                                      : isDriver
                                          ? AppColors.secondary
                                              .withValues(alpha: 0.15)
                                          : AppColors.primaryLight
                                              .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  isAdmin
                                      ? 'OPERATIONS DISPATCHER'
                                      : isDriver
                                          ? 'FLEET DRIVER'
                                          : 'CUSTOMER ACCOUNT',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isAdmin
                                        ? Colors.purple.shade800
                                        : isDriver
                                            ? AppColors.secondary
                                            : AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 2. Personal Information Card
                  Text(
                    'Personal Information',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontSize: 17,
                        ),
                  ),
                  const SizedBox(height: 12),

                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Column(
                      children: [
                        TextField(
                          controller: nameController,
                          decoration: const InputDecoration(
                            labelText: 'Full Name',
                            prefixIcon: Icon(Icons.badge_outlined),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Phone Number',
                            prefixIcon: Icon(Icons.phone_outlined),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: isSaving.value
                                ? null
                                : () async {
                                    isSaving.value = true;
                                    final res = await ref
                                        .read(authRemoteServiceProvider)
                                        .updateUserProfile(
                                          uid: user.uid,
                                          fullName: nameController.text.trim(),
                                          phone: phoneController.text.trim(),
                                        );
                                    isSaving.value = false;

                                    res.fold(
                                      (failure) => AppSnackBar.showError(
                                          context, failure.message),
                                      (_) => AppSnackBar.showSuccess(
                                        context,
                                        'Personal details updated successfully!',
                                      ),
                                    );
                                  },
                            child: isSaving.value
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white),
                                  )
                                : const Text('Save Details'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 3. Driver Vehicle Settings (If Driver)
                  if (isDriver) ...[
                    Text(
                      'Vehicle Settings & Fleet Category',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontSize: 17,
                          ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Select the vehicle category you operate to receive matching delivery requests.',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 12),

                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Vehicle Category Selector
                          Row(
                            children: VehicleType.values.map((v) {
                              final isSelected = selectedVehicle.value == v;
                              return Expanded(
                                child: GestureDetector(
                                  onTap: () => selectedVehicle.value = v,
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 4),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppColors.secondary
                                          : AppColors.background,
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
                                          size: 22,
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
                          const SizedBox(height: 16),

                          TextField(
                            controller: plateController,
                            textCapitalization: TextCapitalization.characters,
                            decoration: const InputDecoration(
                              labelText: 'Plate Number (e.g. LAG-421XY)',
                              prefixIcon:
                                  Icon(Icons.confirmation_number_outlined),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 14),

                          TextField(
                            controller: modelController,
                            decoration: const InputDecoration(
                              labelText:
                                  'Make & Model (e.g. Bajaj Boxer 150)',
                              prefixIcon: Icon(Icons.directions_car_outlined),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 16),

                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.secondary,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                              ),
                              onPressed: isSaving.value
                                  ? null
                                  : () async {
                                      isSaving.value = true;
                                      final res = await ref
                                          .read(authRemoteServiceProvider)
                                          .updateUserProfile(
                                            uid: user.uid,
                                            vehicleType: selectedVehicle.value,
                                            vehiclePlateNumber:
                                                plateController.text.trim(),
                                            vehicleModel:
                                                modelController.text.trim(),
                                          );
                                      isSaving.value = false;

                                      res.fold(
                                        (f) => AppSnackBar.showError(
                                            context, f.message),
                                        (_) => AppSnackBar.showSuccess(
                                          context,
                                          'Vehicle settings updated successfully!',
                                        ),
                                      );
                                    },
                              child: isSaving.value
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white),
                                    )
                                  : const Text('Update Vehicle Settings'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // 4. Quick Account Actions
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Column(
                      children: [
                        // Operations Command Center (Admin or tester shortcut)
                        ListTile(
                          leading: const Icon(
                            Icons.admin_panel_settings_rounded,
                            color: Colors.purple,
                          ),
                          title: const Text('Operations Command Center'),
                          subtitle: const Text(
                              'Live Dispatch Queue, Map & Fleet Roster'),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () =>
                              context.push(AppRoutes.adminDashboardPath),
                        ),
                        const Divider(height: 1),

                        // Role Switcher for Testing & Ecosystem Separation
                        ListTile(
                          leading: const Icon(
                            Icons.swap_horiz_rounded,
                            color: AppColors.primary,
                          ),
                          title: const Text('Switch Active Role Terminal'),
                          subtitle: Text('Current: ${user.role.label}'),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => SimpleDialog(
                                title: const Text('Select Active Role'),
                                children: UserRole.values.map((role) {
                                  final isCurrent = user.role == role;
                                  return SimpleDialogOption(
                                    onPressed: () async {
                                      Navigator.pop(ctx);
                                      if (!isCurrent) {
                                        await ref
                                            .read(authRemoteServiceProvider)
                                            .updateUserProfile(
                                              uid: user.uid,
                                              role: role,
                                            );
                                        if (context.mounted) {
                                          if (role == UserRole.admin) {
                                            context.go(
                                                AppRoutes.adminDashboardPath);
                                          } else if (role == UserRole.driver) {
                                            context.go(
                                                AppRoutes.driverDashboardPath);
                                          } else {
                                            context.go(
                                                AppRoutes.customerHomePath);
                                          }
                                        }
                                      }
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 8.0),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            role.label,
                                            style: TextStyle(
                                              fontWeight: isCurrent
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                              color: isCurrent
                                                  ? AppColors.primary
                                                  : AppColors.textPrimary,
                                            ),
                                          ),
                                          if (isCurrent)
                                            const Icon(
                                              Icons.check,
                                              color: AppColors.primary,
                                              size: 18,
                                            ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            );
                          },
                        ),
                        const Divider(height: 1),

                        ListTile(
                          leading: const Icon(
                            Icons.account_balance_wallet_rounded,
                            color: AppColors.secondary,
                          ),
                          title: const Text('Digital Wallet'),
                          subtitle: Text(
                              'Balance: ₦${user.walletBalance.toStringAsFixed(2)}'),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => context.push(WalletRoute.path),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(
                            Icons.logout_rounded,
                            color: AppColors.error,
                          ),
                          title: const Text(
                            'Sign Out',
                            style: TextStyle(color: AppColors.error),
                          ),
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Sign Out'),
                                content: const Text(
                                    'Are you sure you want to sign out of e-Hailer?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('Cancel'),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.error),
                                    onPressed: () {
                                      Navigator.pop(ctx);
                                      ref
                                          .read(authRemoteServiceProvider)
                                          .signOut();
                                    },
                                    child: const Text('Sign Out'),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
