import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../../core/presentation/styles/app_colors.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/delivery_providers.dart';

class DriverDashboardScreen extends ConsumerWidget {
  const DriverDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfileAsync = ref.watch(currentUserProfileProvider);
    final driver = userProfileAsync.value;
    final availableOrdersAsync = ref.watch(availableOrdersStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Fleet Terminal'),
        actions: [
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
            // Driver Status & Availability Header
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
                    radius: 28,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
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
                          driver?.fullName ?? 'Driver',
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
                  Switch(
                    value: driver?.isAvailable ?? false,
                    activeThumbColor: AppColors.success,
                    onChanged: (val) {
                      // Toggle availability status in Firestore
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Incoming Broadcast Requests (from MyOGA & Deliverzler)
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
                              onPressed: () {
                                if (driver == null) return;
                                ref
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
