import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../core/presentation/styles/app_colors.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../delivery/domain/value_objects/delivery_status.dart';
import '../../../delivery/presentation/providers/dispute_providers.dart';
import '../providers/admin_providers.dart';
import '../widgets/manual_assignment_modal.dart';

/// Central Command Center for Hub Dispatchers and Operations Administrators.
class AdminDashboardScreen extends HookConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metricsAsync = ref.watch(dispatchMetricsStreamProvider);
    final allOrdersAsync = ref.watch(allOrdersStreamProvider);
    final userAsync = ref.watch(currentUserProfileProvider);
    final pendingDisputes = ref.watch(pendingDisputeCountProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Operations Command Center',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              userAsync.value?.fullName ?? 'Hub Dispatcher',
              style: TextStyle(
                fontSize: 12.sp,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics_outlined),
            tooltip: 'Operations Analytics',
            onPressed: () => context.push(AppRoutes.analyticsDashboardPath),
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.push(AppRoutes.profilePath),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(allOrdersStreamProvider);
          ref.invalidate(fleetDriversStreamProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Operational Metrics Grid
              metricsAsync.when(
                loading: () => SizedBox(
                  height: 160.h,
                  child: const Center(child: CircularProgressIndicator()),
                ),
                error: (err, _) => Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Text('Failed to load metrics: $err'),
                ),
                data: (metrics) => Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricTile(
                            context: context,
                            title: 'Pending Dispatch',
                            value: '${metrics.pendingAssignment}',
                            icon: Icons.hourglass_top,
                            color: Colors.orange.shade800,
                            bgColor: Colors.orange.shade50,
                            onTap: () {
                              ref
                                  .read(orderStatusFilterProvider.notifier)
                                  .state = DeliveryStatus.searchingDriver;
                              context.push(AppRoutes.dispatchQueuePath);
                            },
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: _buildMetricTile(
                            context: context,
                            title: 'In Transit',
                            value: '${metrics.inTransit}',
                            icon: Icons.local_shipping,
                            color: Colors.blue.shade700,
                            bgColor: Colors.blue.shade50,
                            onTap: () {
                              ref
                                  .read(orderStatusFilterProvider.notifier)
                                  .state = DeliveryStatus.inTransit;
                              context.push(AppRoutes.dispatchQueuePath);
                            },
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12.h),
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricTile(
                            context: context,
                            title: 'Active Fleet',
                            value:
                                '${metrics.onlineDrivers} / ${metrics.totalDrivers}',
                            icon: Icons.two_wheeler,
                            color: Colors.green.shade700,
                            bgColor: Colors.green.shade50,
                            onTap: () =>
                                context.push(AppRoutes.driverManagementPath),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: _buildMetricTile(
                            context: context,
                            title: 'Delivered',
                            value: '${metrics.deliveredToday}',
                            icon: Icons.task_alt,
                            color: Colors.purple.shade700,
                            bgColor: Colors.purple.shade50,
                            onTap: () {
                              ref
                                  .read(orderStatusFilterProvider.notifier)
                                  .state = DeliveryStatus.delivered;
                              context.push(AppRoutes.dispatchQueuePath);
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20.h),

              // Operational Hub Quick Navigation
              Text(
                'Operations Navigation',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 12.h),

              Row(
                children: [
                  Expanded(
                    child: _buildNavCard(
                      icon: Icons.format_list_bulleted,
                      label: 'Live Queue',
                      subtitle: 'Filter & Assign',
                      onTap: () {
                        ref.read(orderStatusFilterProvider.notifier).state =
                            null;
                        context.push(AppRoutes.dispatchQueuePath);
                      },
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: _buildNavCard(
                      icon: Icons.map,
                      label: 'Fleet Map',
                      subtitle: 'Live Tracking',
                      onTap: () => context.push(AppRoutes.adminMapOverviewPath),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10.h),
              Row(
                children: [
                  Expanded(
                    child: _buildNavCard(
                      icon: Icons.groups,
                      label: 'Fleet Roster',
                      subtitle: 'Manage Drivers',
                      onTap: () => context.push(AppRoutes.driverManagementPath),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: _buildNavCard(
                      icon: Icons.payments_outlined,
                      label: 'Driver Payouts',
                      subtitle: 'Settle Earnings',
                      onTap: () => context.push(AppRoutes.payoutManagementPath),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10.h),
              Row(
                children: [
                  Expanded(
                    child: _buildNavCard(
                      icon: Icons.gavel_rounded,
                      label: 'Disputes & Claims',
                      subtitle: pendingDisputes > 0
                          ? '$pendingDisputes Pending Review'
                          : 'Arbitration',
                      onTap: () =>
                          context.push(AppRoutes.disputeManagementPath),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: _buildNavCard(
                      icon: Icons.travel_explore_rounded,
                      label: 'Waybill Portal',
                      subtitle: 'Public Tracking',
                      onTap: () =>
                          context.push(AppRoutes.publicTrackingPath),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10.h),
              Row(
                children: [
                  Expanded(
                    child: _buildNavCard(
                      icon: Icons.analytics_outlined,
                      label: 'Analytics & KPIs',
                      subtitle: 'Revenue & Reports',
                      onTap: () =>
                          context.push(AppRoutes.analyticsDashboardPath),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: _buildNavCard(
                      icon: Icons.sync_rounded,
                      label: 'Sync Hub Feeds',
                      subtitle: 'Realtime Refresh',
                      onTap: () {
                        ref.invalidate(allOrdersStreamProvider);
                        ref.invalidate(fleetDriversStreamProvider);
                        ref.invalidate(dispatchMetricsStreamProvider);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Operational feeds refreshed'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              SizedBox(height: 24.h),

              // Urgent Dispatch Feed (Pending Orders)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Urgent Orders Needing Dispatch',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      ref.read(orderStatusFilterProvider.notifier).state =
                          DeliveryStatus.searchingDriver;
                      context.push(AppRoutes.dispatchQueuePath);
                    },
                    child: const Text('View All'),
                  ),
                ],
              ),
              SizedBox(height: 8.h),

              allOrdersAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(child: Text('Error: $err')),
                data: (orders) {
                  final pendingOrders = orders
                      .where((o) =>
                          o.status == DeliveryStatus.created ||
                          o.status == DeliveryStatus.searchingDriver)
                      .take(5)
                      .toList();

                  if (pendingOrders.isEmpty) {
                    return Container(
                      padding: EdgeInsets.all(24.h),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              size: 40.w,
                              color: Colors.green,
                            ),
                            SizedBox(height: 8.h),
                            Text(
                              'All orders are currently dispatched!',
                              style: TextStyle(
                                fontSize: 13.sp,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return Column(
                    children: pendingOrders.map((order) {
                      return Container(
                        margin: EdgeInsets.only(bottom: 10.h),
                        padding: EdgeInsets.all(14.w),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(14.r),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(8.w),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.delivery_dining,
                                color: Colors.orange.shade800,
                                size: 20.w,
                              ),
                            ),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    order.trackingNumber,
                                    style: TextStyle(
                                      fontSize: 13.sp,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  SizedBox(height: 2.h),
                                  Text(
                                    '${order.pickupLocation.address} → ${order.dropoffLocation.address}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11.sp,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: 8.w),
                            ElevatedButton(
                              onPressed: () {
                                ManualAssignmentModal.show(context, order);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12.w,
                                  vertical: 8.h,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8.r),
                                ),
                              ),
                              child: Text(
                                'Assign',
                                style: TextStyle(fontSize: 12.sp),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricTile({
    required BuildContext context,
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.r),
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Icon(icon, color: color, size: 20.w),
            ),
            SizedBox(height: 12.h),
            Text(
              value,
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 2.h),
            Text(
              title,
              style: TextStyle(
                fontSize: 12.sp,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavCard({
    required IconData icon,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14.r),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 10.w),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary, size: 24.w),
            SizedBox(height: 6.h),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 2.h),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10.sp,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
