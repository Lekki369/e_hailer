import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../../core/presentation/styles/app_colors.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/delivery_providers.dart';

class CustomerHomeScreen extends HookConsumerWidget {
  const CustomerHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfileAsync = ref.watch(currentUserProfileProvider);
    final user = userProfileAsync.value;
    final searchController = useTextEditingController();
    final isSearching = useState(false);

    Future<void> handleTrackSearch() async {
      final code = searchController.text.trim();
      if (code.isEmpty) return;

      isSearching.value = true;
      final result = await ref
          .read(deliveryRemoteServiceProvider)
          .findOrderByTrackingNumber(code);
      isSearching.value = false;

      result.fold(
        (failure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.error,
              content: Text(failure.message),
            ),
          );
        },
        (foundOrder) {
          searchController.clear();
          context.push(OrderTrackingRoute.pathWithId(foundOrder.id));
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('e-Hailer Logistics'),
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
            // User Greeting & Wallet Card (from MyOGA)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Hello, ${user?.fullName ?? 'Customer'} 👋',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          user?.role.label ?? 'Customer',
                          style: const TextStyle(
                            color: AppColors.secondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Wallet Balance',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₦${(user?.walletBalance ?? 0.0).toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Waybill Consignment Search Bar (from courierManagementSystem)
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.divider),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: searchController,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  hintText: 'Track Any Parcel (e.g. EH-..., WAYBILL-...)',
                  hintStyle: const TextStyle(
                      fontSize: 13, color: AppColors.textMuted),
                  prefixIcon: const Icon(Icons.qr_code_scanner_rounded,
                      color: AppColors.primary),
                  suffixIcon: isSearching.value
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : IconButton(
                          icon: const Icon(Icons.arrow_forward_rounded,
                              color: AppColors.secondary),
                          onPressed: handleTrackSearch,
                        ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                ),
                onSubmitted: (_) => handleTrackSearch(),
              ),
            ),
            const SizedBox(height: 24),

            // Service Mode Options (Express Hailing vs Consignment)
            Text(
              'Select Delivery Service',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontSize: 18,
                  ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _ServiceCard(
                    icon: Icons.electric_bolt_rounded,
                    title: 'Instant Express',
                    subtitle: 'Direct bike dispatch with live GPS tracking',
                    badgeColor: AppColors.secondary,
                    onTap: () {
                      context.push(ExpressBookingRoute.path);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ServiceCard(
                    icon: Icons.inventory_2_rounded,
                    title: 'Hub Consignment',
                    subtitle: 'Volumetric boxes, freight & waybill tracking',
                    badgeColor: AppColors.info,
                    onTap: () {
                      context.push(ConsignmentCreationRoute.path);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // Recent Deliveries Header
            Text(
              'Recent Deliveries',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontSize: 18,
                  ),
            ),
            const SizedBox(height: 12),

            // Orders Stream from Firestore
            if (user != null)
              Consumer(
                builder: (context, ref, _) {
                  final ordersAsync =
                      ref.watch(customerOrdersStreamProvider(user.uid));

                  return ordersAsync.when(
                    data: (orders) {
                      if (orders.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          alignment: Alignment.center,
                          child: const Text(
                            'No shipments found. Book your first delivery above!',
                            style: TextStyle(color: AppColors.textSecondary),
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
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: AppColors.divider),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(16),
                              leading: CircleAvatar(
                                backgroundColor:
                                    AppColors.secondary.withValues(alpha: 0.15),
                                child: const Icon(
                                  Icons.local_shipping,
                                  color: AppColors.secondary,
                                ),
                              ),
                              title: Text(
                                order.trackingNumber,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(
                                    'To: ${order.dropoffLocation.address}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    order.status.label,
                                    style: TextStyle(
                                      color: order.status.isCompleted
                                          ? AppColors.success
                                          : AppColors.secondary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              trailing: const Icon(
                                Icons.chevron_right_rounded,
                                color: AppColors.textSecondary,
                              ),
                              onTap: () {
                                context.push(OrderTrackingRoute.pathWithId(order.id));
                              },
                            ),
                          );
                        },
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Text('Error: $e'),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color badgeColor;
  final VoidCallback onTap;

  const _ServiceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badgeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: badgeColor.withValues(alpha: 0.12),
              child: Icon(icon, color: badgeColor),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
