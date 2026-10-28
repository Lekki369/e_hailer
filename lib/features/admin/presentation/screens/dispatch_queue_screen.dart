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
/// sort, search, and perform single or batch driver assignments.
class DispatchQueueScreen extends StatefulHookConsumerWidget {
  const DispatchQueueScreen({super.key});

  @override
  ConsumerState<DispatchQueueScreen> createState() =>
      _DispatchQueueScreenState();
}

class _DispatchQueueScreenState extends ConsumerState<DispatchQueueScreen> {
  bool _isMultiSelect = false;
  final Set<String> _selectedOrderIds = {};

  @override
  Widget build(BuildContext context) {
    final filteredOrders = ref.watch(filteredOrdersProvider);
    final allOrdersAsync = ref.watch(allOrdersStreamProvider);
    final selectedStatus = ref.watch(orderStatusFilterProvider);
    final isDelayedOnly = ref.watch(delayedFilterProvider);
    final currentSort = ref.watch(queueSortOptionProvider);

    // Compute delayed order count
    final delayedCount = allOrdersAsync.maybeWhen(
      data: (orders) => orders.where((o) => o.isDelayed).length,
      orElse: () => 0,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          _isMultiSelect
              ? '${_selectedOrderIds.length} Selected'
              : 'Live Dispatch Queue',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          TextButton.icon(
            icon: Icon(
              _isMultiSelect ? Icons.close : Icons.checklist_rtl,
              size: 18.w,
              color: AppColors.primary,
            ),
            label: Text(
              _isMultiSelect ? 'Cancel' : 'Select',
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            onPressed: () {
              setState(() {
                _isMultiSelect = !_isMultiSelect;
                if (!_isMultiSelect) {
                  _selectedOrderIds.clear();
                }
              });
            },
          ),
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
          // Search & Filters Header
          Container(
            color: AppColors.surface,
            padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 12.h),
            child: Column(
              children: [
                // Search Input & Sort Menu
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        onChanged: (val) {
                          ref.read(orderSearchQueryProvider.notifier).state = val;
                        },
                        decoration: InputDecoration(
                          hintText: 'Search Waybill, Customer, Zone...',
                          hintStyle: TextStyle(
                            fontSize: 13.sp,
                            color: AppColors.textSecondary,
                          ),
                          prefixIcon: const Icon(Icons.search, size: 20),
                          filled: true,
                          fillColor: AppColors.background,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 14.w,
                            vertical: 8.h,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.r),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    // Sorting dropdown button
                    PopupMenuButton<QueueSortOption>(
                      initialValue: currentSort,
                      icon: Container(
                        padding: EdgeInsets.all(10.w),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: const Icon(Icons.sort, color: AppColors.primary),
                      ),
                      tooltip: 'Sort Queue',
                      onSelected: (sort) {
                        ref.read(queueSortOptionProvider.notifier).state = sort;
                      },
                      itemBuilder: (ctx) => [
                        for (final opt in QueueSortOption.values)
                          PopupMenuItem(
                            value: opt,
                            child: Row(
                              children: [
                                Icon(
                                  opt == currentSort
                                      ? Icons.check
                                      : Icons.radio_button_unchecked,
                                  size: 16.w,
                                  color: opt == currentSort
                                      ? AppColors.primary
                                      : Colors.grey,
                                ),
                                SizedBox(width: 8.w),
                                Text(opt.label),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 10.h),

                // Status & Delayed Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // All Orders
                      _buildChip(
                        label: 'All Orders',
                        isSelected: selectedStatus == null && !isDelayedOnly,
                        onTap: () {
                          ref.read(delayedFilterProvider.notifier).state = false;
                          ref.read(orderStatusFilterProvider.notifier).state =
                              null;
                        },
                      ),
                      SizedBox(width: 8.w),

                      // Delayed Alert Filter Chip
                      _buildDelayedChip(
                        count: delayedCount,
                        isSelected: isDelayedOnly,
                        onTap: () {
                          ref.read(delayedFilterProvider.notifier).state =
                              !isDelayedOnly;
                          if (!isDelayedOnly) {
                            ref
                                .read(orderStatusFilterProvider.notifier)
                                .state = null;
                          }
                        },
                      ),
                      SizedBox(width: 8.w),

                      // Unassigned / Pending
                      _buildChip(
                        label: 'Unassigned',
                        isSelected: !isDelayedOnly &&
                            selectedStatus == DeliveryStatus.searchingDriver,
                        onTap: () {
                          ref.read(delayedFilterProvider.notifier).state = false;
                          ref.read(orderStatusFilterProvider.notifier).state =
                              DeliveryStatus.searchingDriver;
                        },
                      ),
                      SizedBox(width: 8.w),

                      // Assigned
                      _buildChip(
                        label: 'Assigned',
                        isSelected: !isDelayedOnly &&
                            selectedStatus == DeliveryStatus.assigned,
                        onTap: () {
                          ref.read(delayedFilterProvider.notifier).state = false;
                          ref.read(orderStatusFilterProvider.notifier).state =
                              DeliveryStatus.assigned;
                        },
                      ),
                      SizedBox(width: 8.w),

                      // In Transit
                      _buildChip(
                        label: 'In Transit',
                        isSelected: !isDelayedOnly &&
                            selectedStatus == DeliveryStatus.inTransit,
                        onTap: () {
                          ref.read(delayedFilterProvider.notifier).state = false;
                          ref.read(orderStatusFilterProvider.notifier).state =
                              DeliveryStatus.inTransit;
                        },
                      ),
                      SizedBox(width: 8.w),

                      // Delivered
                      _buildChip(
                        label: 'Delivered',
                        isSelected: !isDelayedOnly &&
                            selectedStatus == DeliveryStatus.delivered,
                        onTap: () {
                          ref.read(delayedFilterProvider.notifier).state = false;
                          ref.read(orderStatusFilterProvider.notifier).state =
                              DeliveryStatus.delivered;
                        },
                      ),
                      SizedBox(width: 8.w),

                      // Cancelled
                      _buildChip(
                        label: 'Cancelled',
                        isSelected: !isDelayedOnly &&
                            selectedStatus == DeliveryStatus.cancelled,
                        onTap: () {
                          ref.read(delayedFilterProvider.notifier).state = false;
                          ref.read(orderStatusFilterProvider.notifier).state =
                              DeliveryStatus.cancelled;
                        },
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
                    return _buildOrderCard(order);
                  },
                );
              },
            ),
          ),
        ],
      ),
      // Persistent Batch Assignment Bar
      bottomNavigationBar: _isMultiSelect && _selectedOrderIds.isNotEmpty
          ? Container(
              padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 20.h),
              decoration: BoxDecoration(
                color: AppColors.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_selectedOrderIds.length} Orders Selected',
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            'Batch Dispatch Routing',
                            style: TextStyle(
                              fontSize: 11.sp,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.send_rounded),
                      label: const Text('Batch Assign Driver'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          horizontal: 16.w,
                          vertical: 12.h,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                      ),
                      onPressed: () {
                        final selectedOrders = filteredOrders
                            .where((o) => _selectedOrderIds.contains(o.id))
                            .toList();
                        ManualAssignmentModal.showBatch(
                          context,
                          selectedOrders,
                        );
                      },
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
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
      onSelected: (_) => onTap(),
    );
  }

  Widget _buildDelayedChip({
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return ChoiceChip(
      avatar: Icon(
        Icons.warning_amber_rounded,
        size: 16.w,
        color: isSelected ? Colors.white : Colors.red.shade700,
      ),
      label: Text('Delayed ($count)'),
      labelStyle: TextStyle(
        fontSize: 12.sp,
        fontWeight: FontWeight.bold,
        color: isSelected ? Colors.white : Colors.red.shade700,
      ),
      selected: isSelected,
      selectedColor: Colors.red.shade700,
      backgroundColor: Colors.red.shade50,
      onSelected: (_) => onTap(),
    );
  }

  Widget _buildOrderCard(DeliveryOrder order) {
    final isUnassigned = order.driverId == null &&
        order.status != DeliveryStatus.delivered &&
        order.status != DeliveryStatus.cancelled;
    final isSelected = _selectedOrderIds.contains(order.id);
    final waitingMinutes =
        DateTime.now().difference(order.createdAt).inMinutes;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: isSelected
              ? AppColors.primary
              : order.isDelayed
                  ? Colors.red.shade300
                  : Colors.transparent,
          width: isSelected || order.isDelayed ? 1.5 : 0,
        ),
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
          // Header: Checkbox (in multi-select) / Waybill / Tags
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  if (_isMultiSelect) ...[
                    Checkbox(
                      value: isSelected,
                      activeColor: AppColors.primary,
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _selectedOrderIds.add(order.id);
                          } else {
                            _selectedOrderIds.remove(order.id);
                          }
                        });
                      },
                    ),
                  ],
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
                  SizedBox(width: 8.w),
                  // Pickup Zone Badge
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 6.w,
                      vertical: 2.h,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(6.r),
                    ),
                    child: Text(
                      order.pickupZone,
                      style: TextStyle(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  if (order.isDelayed) ...[
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 6.w,
                        vertical: 2.h,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(6.r),
                      ),
                      child: Text(
                        'DELAYED',
                        style: TextStyle(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade900,
                        ),
                      ),
                    ),
                    SizedBox(width: 6.w),
                  ],
                  _buildStatusPill(order.status),
                ],
              ),
            ],
          ),
          SizedBox(height: 10.h),

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

          // Customer, Driver, Fare & Age
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
                        : 'Driver: Unassigned ($waitingMinutes mins ago)',
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
