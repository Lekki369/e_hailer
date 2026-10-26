import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../core/presentation/styles/app_colors.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../delivery/domain/entities/delivery_order.dart';
import '../../../delivery/domain/value_objects/delivery_status.dart';
import '../../../wallet/presentation/widgets/fare_breakdown_bottom_sheet.dart';
import '../providers/admin_providers.dart';
import '../widgets/manual_assignment_modal.dart';

/// Full-featured operational dispatch queue allowing hub operators to filter,
/// search, inspect, and manually assign drivers to incoming delivery orders.
class DispatchQueueScreen extends HookConsumerWidget {
  const DispatchQueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filteredOrders = ref.watch(filteredOrdersProvider);
    final allOrdersAsync = ref.watch(allOrdersStreamProvider);
    final selectedFilter = ref.watch(orderStatusFilterProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Live Dispatch Queue',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(allOrdersStreamProvider);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search & Filter header
          Container(
            color: AppColors.surface,
            padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 12.h),
            child: Column(
              children: [
                // Search Input
                TextField(
                  onChanged: (val) {
                    ref.read(orderSearchQueryProvider.notifier).state = val;
                  },
                  decoration: InputDecoration(
                    hintText: 'Search Waybill, Customer, or Phone...',
                    hintStyle: TextStyle(
                      fontSize: 13.sp,
                      color: AppColors.textSecondary,
                    ),
                    prefixIcon: const Icon(Icons.search, size: 20),
                    filled: true,
                    fillColor: AppColors.background,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 10.h,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                SizedBox(height: 10.h),

                // Status Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip(
                        ref: ref,
                        label: 'All Orders',
                        status: null,
                        isSelected: selectedFilter == null,
                      ),
                      SizedBox(width: 8.w),
                      _buildFilterChip(
                        ref: ref,
                        label: 'Pending',
                        status: DeliveryStatus.searchingDriver,
                        isSelected:
                            selectedFilter == DeliveryStatus.searchingDriver,
                      ),
                      SizedBox(width: 8.w),
                      _buildFilterChip(
                        ref: ref,
                        label: 'Assigned',
                        status: DeliveryStatus.assigned,
                        isSelected: selectedFilter == DeliveryStatus.assigned,
                      ),
                      SizedBox(width: 8.w),
                      _buildFilterChip(
                        ref: ref,
                        label: 'In Transit',
                        status: DeliveryStatus.inTransit,
                        isSelected: selectedFilter == DeliveryStatus.inTransit,
                      ),
                      SizedBox(width: 8.w),
                      _buildFilterChip(
                        ref: ref,
                        label: 'Delivered',
                        status: DeliveryStatus.delivered,
                        isSelected: selectedFilter == DeliveryStatus.delivered,
                      ),
                      SizedBox(width: 8.w),
                      _buildFilterChip(
                        ref: ref,
                        label: 'Cancelled',
                        status: DeliveryStatus.cancelled,
                        isSelected: selectedFilter == DeliveryStatus.cancelled,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Orders Feed
          Expanded(
            child: allOrdersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Text('Error loading orders: $err'),
              ),
              data: (_) {
                if (filteredOrders.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          size: 64.w,
                          color: AppColors.textSecondary.withValues(alpha: 0.5),
                        ),
                        SizedBox(height: 12.h),
                        Text(
                          'No orders matching the active criteria.',
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: EdgeInsets.all(16.w),
                  itemCount: filteredOrders.length,
                  separatorBuilder: (_, __) => SizedBox(height: 12.h),
                  itemBuilder: (ctx, idx) {
                    final order = filteredOrders[idx];
                    return _buildOrderCard(context, ref, order);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required WidgetRef ref,
    required String label,
    required DeliveryStatus? status,
    required bool isSelected,
  }) {
    return ChoiceChip(
      label: Text(label),
      labelStyle: TextStyle(
        fontSize: 12.sp,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? Colors.white : AppColors.textPrimary,
      ),
      selected: isSelected,
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.background,
      onSelected: (_) {
        ref.read(orderStatusFilterProvider.notifier).state = status;
      },
    );
  }

  Widget _buildOrderCard(
    BuildContext context,
    WidgetRef ref,
    DeliveryOrder order,
  ) {
    final isUnassigned = order.driverId == null &&
        order.status != DeliveryStatus.delivered &&
        order.status != DeliveryStatus.cancelled;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Waybill & Status Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.qr_code,
                    size: 18.w,
                    color: AppColors.primary,
                  ),
                  SizedBox(width: 6.w),
                  Text(
                    order.trackingNumber,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              _buildStatusPill(order.status),
            ],
          ),
          SizedBox(height: 12.h),

          // Route: Pickup & Dropoff
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Icon(Icons.trip_origin, size: 14.w, color: Colors.green),
                  Container(
                    width: 1.5.w,
                    height: 24.h,
                    color: Colors.grey.shade300,
                  ),
                  Icon(Icons.location_on, size: 14.w, color: Colors.red),
                ],
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.pickupLocation.address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 14.h),
                    Text(
                      order.dropoffLocation.address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),

          const Divider(height: 1),
          SizedBox(height: 10.h),

          // Customer, Driver, Fare & Action
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Customer: ${order.customerName}',
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    order.driverName != null
                        ? 'Driver: ${order.driverName}'
                        : 'Driver: Unassigned',
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: isUnassigned
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isUnassigned
                          ? Colors.orange.shade800
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () => FareBreakdownBottomSheet.show(context, order),
                borderRadius: BorderRadius.circular(8.r),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
                  child: Row(
                    children: [
                      Text(
                        '₦${order.pricing.totalFare.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      SizedBox(width: 4.w),
                      Icon(
                        Icons.info_outline,
                        size: 14.w,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),

          // Actions
          Row(
            children: [
              // Assign / Reassign Button
              if (order.status != DeliveryStatus.delivered &&
                  order.status != DeliveryStatus.cancelled) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    icon: Icon(
                      isUnassigned ? Icons.person_add : Icons.sync,
                      size: 16.w,
                    ),
                    label: Text(
                      isUnassigned ? 'Assign Driver' : 'Reassign',
                      style: TextStyle(fontSize: 12.sp),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                    ),
                    onPressed: () {
                      ManualAssignmentModal.show(context, order);
                    },
                  ),
                ),
                SizedBox(width: 8.w),
              ],

              // View / Track Button
              Expanded(
                child: ElevatedButton.icon(
                  icon: Icon(Icons.location_searching, size: 16.w),
                  label: Text('Live Track', style: TextStyle(fontSize: 12.sp)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
                  onPressed: () {
                    context.push(AppRoutes.orderTracking(order.id));
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPill(DeliveryStatus status) {
    Color bg;
    Color fg;

    switch (status) {
      case DeliveryStatus.created:
      case DeliveryStatus.searchingDriver:
        bg = Colors.amber.shade100;
        fg = Colors.amber.shade900;
        break;
      case DeliveryStatus.assigned:
      case DeliveryStatus.arrivedPickup:
        bg = Colors.blue.shade100;
        fg = Colors.blue.shade900;
        break;
      case DeliveryStatus.pickedUp:
      case DeliveryStatus.inTransit:
      case DeliveryStatus.arrivedDropoff:
        bg = Colors.purple.shade100;
        fg = Colors.purple.shade900;
        break;
      case DeliveryStatus.delivered:
        bg = Colors.green.shade100;
        fg = Colors.green.shade900;
        break;
      case DeliveryStatus.failedDelivery:
      case DeliveryStatus.returnedToHub:
      case DeliveryStatus.cancelled:
        bg = Colors.red.shade100;
        fg = Colors.red.shade900;
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 11.sp,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}
