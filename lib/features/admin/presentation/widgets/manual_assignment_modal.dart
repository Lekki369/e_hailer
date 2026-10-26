import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../core/presentation/styles/app_colors.dart';
import '../../../delivery/domain/entities/delivery_order.dart';
import '../../domain/entities/fleet_driver_summary.dart';
import '../providers/admin_providers.dart';

/// Modal bottom sheet to assign or reassign a delivery order to an active fleet driver.
class ManualAssignmentModal extends StatefulHookConsumerWidget {
  final DeliveryOrder order;

  const ManualAssignmentModal({
    super.key,
    required this.order,
  });

  static Future<void> show(BuildContext context, DeliveryOrder order) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ManualAssignmentModal(order: order),
    );
  }

  @override
  ConsumerState<ManualAssignmentModal> createState() =>
      _ManualAssignmentModalState();
}

class _ManualAssignmentModalState extends ConsumerState<ManualAssignmentModal> {
  FleetDriverSummary? _selectedDriver;
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    final driversAsync = ref.watch(fleetDriversStreamProvider);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 24.h + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
          ),
          SizedBox(height: 16.h),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Assign Fleet Driver',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          SizedBox(height: 8.h),

          // Order summary banner
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Waybill: ${widget.order.trackingNumber}',
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    Text(
                      widget.order.vehicleType.label,
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 6.h),
                Text(
                  'To: ${widget.order.dropoffLocation.address}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16.h),

          Text(
            'Select Driver',
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 8.h),

          // Drivers list
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: 260.h),
            child: driversAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (err, _) => Center(
                child: Text(
                  'Error loading fleet: $err',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
              data: (drivers) {
                if (drivers.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.h),
                      child: Text(
                        'No registered drivers in the system.',
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  );
                }

                // Sort: online available drivers first
                final sorted = List<FleetDriverSummary>.from(drivers)
                  ..sort((a, b) {
                    if (a.isAvailable && !b.isAvailable) return -1;
                    if (!a.isAvailable && b.isAvailable) return 1;
                    return a.fullName.compareTo(b.fullName);
                  });

                return ListView.separated(
                  shrinkWrap: true,
                  itemCount: sorted.length,
                  separatorBuilder: (_, __) => SizedBox(height: 8.h),
                  itemBuilder: (ctx, idx) {
                    final driver = sorted[idx];
                    final isSelected = _selectedDriver?.uid == driver.uid;

                    return InkWell(
                      onTap: () {
                        setState(() {
                          _selectedDriver = driver;
                        });
                      },
                      borderRadius: BorderRadius.circular(12.r),
                      child: Container(
                        padding: EdgeInsets.all(12.w),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary.withValues(alpha: 0.08)
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : Colors.grey.shade200,
                            width: isSelected ? 1.5 : 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            // Status indicator dot
                            Container(
                              width: 10.w,
                              height: 10.w,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: driver.isAvailable
                                    ? Colors.green
                                    : Colors.grey.shade400,
                              ),
                            ),
                            SizedBox(width: 12.w),

                            // Driver info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    driver.fullName,
                                    style: TextStyle(
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  SizedBox(height: 2.h),
                                  Text(
                                    '${driver.vehicleType.label} • ${driver.vehiclePlateNumber ?? "No Plate"} • ⭐ ${driver.rating.toStringAsFixed(1)}',
                                    style: TextStyle(
                                      fontSize: 12.sp,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Radio icon
                            Icon(
                              isSelected
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_off,
                              color: isSelected
                                  ? AppColors.primary
                                  : Colors.grey.shade400,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SizedBox(height: 20.h),

          // Dispatch Action Button
          ElevatedButton(
            onPressed: (_selectedDriver == null || _isSubmitting)
                ? null
                : () async {
                    setState(() {
                      _isSubmitting = true;
                    });

                    final adminService = ref.read(adminRemoteServiceProvider);
                    final result = await adminService.assignDriverToOrder(
                      orderId: widget.order.id,
                      driver: _selectedDriver!,
                    );

                    if (mounted) {
                      setState(() {
                        _isSubmitting = false;
                      });

                      result.fold(
                        (failure) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(failure.message),
                              backgroundColor: Colors.red,
                            ),
                          );
                        },
                        (_) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Order assigned to ${_selectedDriver!.fullName}!',
                              ),
                              backgroundColor: Colors.green,
                            ),
                          );
                        },
                      );
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 14.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
            child: _isSubmitting
                ? SizedBox(
                    height: 20.h,
                    width: 20.h,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    'Confirm Dispatch Assignment',
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
