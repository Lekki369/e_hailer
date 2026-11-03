import '../../../../core/presentation/widgets/adaptive_layout.dart';
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
    final isStaff = user?.role.isStaff ?? false;

    final nameController = useTextEditingController(text: user?.fullName ?? '');
    final phoneController = useTextEditingController(text: user?.phone ?? '');
    final plateController = useTextEditingController(
      text: user?.vehiclePlateNumber ?? '',
    );
    final modelController = useTextEditingController(
      text: user?.vehicleModel ?? '',
    );

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
      appBar: AppBar(title: const Text('Profile & Settings')),
      body: user == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: AdaptiveContent(
                maxWidth: 720,
                scrollable: false,
                padding: EdgeInsets.zero,
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
                            backgroundColor: AppColors.primary.withValues(
                              alpha: 0.1,
                            ),
                            child: Icon(
                              isStaff
                                  ? Icons.admin_panel_settings_rounded
                                  : isDriver
                                  ? Icons.two_wheeler_rounded
                                  : Icons.person_rounded,
                              size: 36,
                              color: isStaff
                                  ? Colors.purple
                                  : AppColors.primary,
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
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isStaff
                                        ? Colors.purple.shade50
                                        : isDriver
                                        ? AppColors.secondary.withValues(
                                            alpha: 0.15,
                                          )
                                        : AppColors.primaryLight.withValues(
                                            alpha: 0.1,
                                          ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    user.role.label,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: isStaff
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
                      style: Theme.of(
                        context,
                      ).textTheme.titleLarge?.copyWith(fontSize: 17),
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
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                              ),
                              onPressed: isSaving.value
                                  ? null
                                  : () async {
                                      final name = nameController.text.trim();
                                      final phone = phoneController.text.trim();

                                      if (name.isEmpty) {
                                        AppSnackBar.showWarning(
                                          context,
                                          'Please enter your full name.',
                                          title: 'Name Required',
                                        );
                                        return;
                                      }

                                      if (phone.isEmpty) {
                                        AppSnackBar.showWarning(
                                          context,
                                          'Please enter your contact phone number.',
                                          title: 'Phone Required',
                                        );
                                        return;
                                      }

                                      isSaving.value = true;
                                      final res = await ref
                                          .read(authRemoteServiceProvider)
                                          .updateUserProfile(
                                            uid: user.uid,
                                            fullName: name,
                                            phone: phone,
                                          );
                                      if (!context.mounted) return;
                                      isSaving.value = false;

                                      res.fold(
                                        (failure) => AppSnackBar.showError(
                                          context,
                                          failure.message,
                                        ),
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
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
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
                        style: Theme.of(
                          context,
                        ).textTheme.titleLarge?.copyWith(fontSize: 17),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        user.driverApproved == true
                            ? 'Your approved vehicle is locked. Ask an administrator to revoke approval before changing it, then request approval again.'
                            : 'Select the vehicle category you operate. An administrator must approve your vehicle and operating area before you receive jobs.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
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
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Vehicle Category Selector
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: VehicleType.values.map((vehicle) {
                                return ChoiceChip(
                                  selected: selectedVehicle.value == vehicle,
                                  onSelected:
                                      isSaving.value ||
                                          user.driverApproved == true
                                      ? null
                                      : (_) => selectedVehicle.value = vehicle,
                                  avatar: Icon(
                                    vehicle == VehicleType.bike
                                        ? Icons.two_wheeler
                                        : vehicle == VehicleType.car
                                        ? Icons.directions_car
                                        : Icons.local_shipping,
                                    size: 20,
                                  ),
                                  label: Text(
                                    '${vehicle.name.toUpperCase()} · ${vehicle.rateMultiplier}×',
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 16),

                            TextField(
                              controller: plateController,
                              enabled: user.driverApproved != true,
                              textCapitalization: TextCapitalization.characters,
                              decoration: const InputDecoration(
                                labelText: 'Plate Number (e.g. LAG-421XY)',
                                prefixIcon: Icon(
                                  Icons.confirmation_number_outlined,
                                ),
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 14),

                            TextField(
                              controller: modelController,
                              enabled: user.driverApproved != true,
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
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                ),
                                onPressed:
                                    isSaving.value ||
                                        user.driverApproved == true
                                    ? null
                                    : () async {
                                        final plate = plateController.text
                                            .trim();
                                        final model = modelController.text
                                            .trim();

                                        if (plate.isEmpty) {
                                          AppSnackBar.showWarning(
                                            context,
                                            'Please enter your vehicle license plate number.',
                                            title: 'Plate Number Required',
                                          );
                                          return;
                                        }

                                        if (model.isEmpty) {
                                          AppSnackBar.showWarning(
                                            context,
                                            'Please enter your vehicle model name.',
                                            title: 'Vehicle Model Required',
                                          );
                                          return;
                                        }

                                        isSaving.value = true;
                                        final res = await ref
                                            .read(authRemoteServiceProvider)
                                            .updateUserProfile(
                                              uid: user.uid,
                                              vehicleType:
                                                  selectedVehicle.value,
                                              vehiclePlateNumber: plate,
                                              vehicleModel: model,
                                            );
                                        if (!context.mounted) return;
                                        isSaving.value = false;

                                        res.fold(
                                          (f) => AppSnackBar.showError(
                                            context,
                                            f.message,
                                          ),
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
                                          color: Colors.white,
                                        ),
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
                    Material(
                      color: Colors.white,
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: AppColors.divider),
                      ),
                      child: Column(
                        children: [
                          // Role-specific operations navigation
                          if (isAdmin)
                            ListTile(
                              leading: const Icon(
                                Icons.admin_panel_settings_rounded,
                                color: Colors.purple,
                              ),
                              title: const Text('Operations Command Center'),
                              subtitle: const Text(
                                'Live Dispatch Queue, Map & Fleet Roster',
                              ),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: () =>
                                  context.push(AppRoutes.adminDashboardPath),
                            ),
                          if (isAdmin) const Divider(height: 1),

                          ListTile(
                            leading: const Icon(
                              Icons.account_balance_wallet_rounded,
                              color: AppColors.secondary,
                            ),
                            title: const Text('Digital Wallet'),
                            subtitle: Text(
                              'Balance: ₦${user.walletBalance.toStringAsFixed(2)}',
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () => context.push(WalletRoute.path),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: const Icon(Icons.policy_outlined),
                            title: const Text('Open-source licenses'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => showLicensePage(
                              context: context,
                              applicationName: 'e-Hailer',
                              applicationLegalese:
                                  '© 2026 Lekki369 and e-Hailer contributors',
                            ),
                          ),
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
                                    'Are you sure you want to sign out of e-Hailer?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx),
                                      child: const Text('Cancel'),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.error,
                                      ),
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
            ),
    );
  }
}
