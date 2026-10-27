import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../core/presentation/styles/app_colors.dart';
import '../../../../core/presentation/widgets/app_snackbar.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/delivery_providers.dart';

class DriverDashboardScreen extends ConsumerWidget {
  const DriverDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfileAsync = ref.watch(currentUserProfileProvider);
    final driver = userProfileAsync.value;
    final availableOrdersAsync = ref.watch(availableOrdersStreamProvider);
    final activeOrdersAsync = driver != null
        ? ref.watch(driverActiveOrdersStreamProvider(driver.uid))
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Fleet Terminal'),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_balance_wallet_rounded),
            tooltip: 'Digital Wallet',
            onPressed: () => context.push(WalletRoute.path),
          ),
          IconButton(
            icon: const Icon(Icons.person_outline_rounded),
            tooltip: 'Profile & Settings',
            onPressed: () => context.push(ProfileRoute.path),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => ref.read(authRemoteServiceProvider).signOut(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Driver Profile & Availability Toggle Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.divider),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor:
                            AppColors.primary.withValues(alpha: 0.1),
                        child: const Icon(
                          Icons.two_wheeler_rounded,
                          size: 30,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              driver?.fullName ?? 'Fleet Driver',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.star_rounded,
                                  size: 16,
                                  color: Colors.amber.shade700,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${driver?.rating ?? 5.0} • ${driver?.vehicleType?.label ?? 'Motorcycle'}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Column(
                        children: [
                          Switch(
                            value: driver?.isAvailable ?? false,
                            activeThumbColor: AppColors.success,
                            onChanged: (val) async {
                              if (driver == null) return;
                              final res = await ref
                                  .read(authRemoteServiceProvider)
                                  .setDriverAvailability(
                                    uid: driver.uid,
                                    isAvailable: val,
                                  );
                              res.fold(
                                (failure) {
                                  AppSnackBar.showError(context, failure.message);
                                },
                                (_) {
                                  if (val) {
                                    AppSnackBar.showSuccess(
                                      context,
                                      'You are now ONLINE and broadcasting availability',
                                    );
                                  } else {
                                    AppSnackBar.showInfo(
                                      context,
                                      'You are now OFFLINE',
                                    );
                                  }
                                },
                              );
                            },
                          ),
                          Text(
                            (driver?.isAvailable ?? false) ? 'ONLINE' : 'OFFLINE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: (driver?.isAvailable ?? false)
                                  ? AppColors.success
                                  : AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(height: 24),

                  // Digital Wallet Quick Balance
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => context.push(WalletRoute.path),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.account_balance_wallet_rounded,
                                  size: 18, color: AppColors.secondary),
                              SizedBox(width: 8),
                              Text(
                                'Digital Wallet Earnings',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Text(
                                '₦${(driver?.walletBalance ?? 0.0).toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.secondary,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.chevron_right_rounded,
                                  size: 20, color: AppColors.textSecondary),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 2. Active Ongoing Orders Section (If assigned to this driver)
            if (activeOrdersAsync != null)
              activeOrdersAsync.when(
                data: (activeOrders) {
                  if (activeOrders.isEmpty) return const SizedBox.shrink();
                  final active = activeOrders.first;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.secondary),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.delivery_dining_rounded,
                                      color: AppColors.secondary),
                                  SizedBox(width: 8),
                                  Text(
                                    'Active Trip in Progress',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: AppColors.secondary,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.secondary,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  active.status.name.toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            active.dropoffLocation.address,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.navigation_rounded),
                            label: const Text('Open Active Delivery Terminal'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.secondary,
                            ),
                            onPressed: () {
                              context.push(
                                  ActiveDeliveryRoute.pathWithId(active.id));
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),

            // 3. Incoming Broadcast Requests (from MyOGA & Deliverzler)
            Text(
              'Incoming Delivery Requests',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontSize: 18,
                  ),
            ),
            const SizedBox(height: 12),

            availableOrdersAsync.when(
              data: (orders) {
                if (orders.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(40),
                    alignment: Alignment.center,
                    child: const Column(
                      children: [
                        Icon(
                          Icons.radar_rounded,
                          size: 48,
                          color: AppColors.textMuted,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Scanning for nearby requests...',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: orders.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final order = orders[index];
                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: const BorderSide(color: AppColors.divider),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  order.trackingNumber,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '₦${order.pricing.totalFare.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.secondary,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 20),
                            Row(
                              children: [
                                const Icon(
                                  Icons.circle,
                                  size: 10,
                                  color: AppColors.success,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    order.pickupLocation.address,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_on,
                                  size: 14,
                                  color: AppColors.error,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    order.dropoffLocation.address,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () async {
                                if (driver == null) return;
                                final result = await ref
                                    .read(deliveryRemoteServiceProvider)
                                    .acceptJob(
                                      orderId: order.id,
                                      driverId: driver.uid,
                                      driverName: driver.fullName,
                                      driverPhone: driver.phone,
                                      driverLatitude:
                                          order.pickupLocation.latitude,
                                      driverLongitude:
                                          order.pickupLocation.longitude,
                                    );

                                result.fold(
                                  (failure) {
                                    AppSnackBar.showError(context, failure.message);
                                  },
                                  (_) {
                                    context.push(
                                      ActiveDeliveryRoute.pathWithId(order.id),
                                    );
                                  },
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.secondary,
                              ),
                              child: const Text('Accept Delivery Job'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Error: $e'),
            ),
          ],
        ),
      ),
    );
  }
}
