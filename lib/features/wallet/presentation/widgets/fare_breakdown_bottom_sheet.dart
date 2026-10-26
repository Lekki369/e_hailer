import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/presentation/styles/app_colors.dart';
import '../../../delivery/domain/entities/delivery_order.dart';

/// Modal bottom sheet displaying complete fare calculation, revenue split (80/20),
/// payment method, and settlement status for an order.
class FareBreakdownBottomSheet extends StatelessWidget {
  final DeliveryOrder order;

  const FareBreakdownBottomSheet({
    super.key,
    required this.order,
  });

  static Future<void> show(BuildContext context, DeliveryOrder order) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FareBreakdownBottomSheet(order: order),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pricing = order.pricing;
    final driverEarnings =
        pricing.driverEarnings ?? (pricing.totalFare * 0.8);
    final platformCommission =
        pricing.platformCommission ?? (pricing.totalFare * 0.2);

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

          // Title & Waybill
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Financial Fare Breakdown',
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
          Text(
            'Consignment: ${order.trackingNumber}',
            style: TextStyle(
              fontSize: 12.sp,
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(height: 16.h),

          // Fare Elements Card
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(
              children: [
                _buildRow(
                  label: 'Base Fare (${order.vehicleType.label})',
                  amount: pricing.baseFare,
                ),
                SizedBox(height: 8.h),
                _buildRow(
                  label:
                      'Distance (${order.distanceKm.toStringAsFixed(1)} km @ ₦120/km)',
                  amount: pricing.distanceFare,
                ),
                SizedBox(height: 8.h),
                _buildRow(
                  label:
                      'Weight Surcharge (${order.parcel.billableWeightKg.toStringAsFixed(1)} kg)',
                  amount: pricing.weightSurcharge,
                ),
                if (order.parcel.isFragile) ...[
                  SizedBox(height: 8.h),
                  _buildRow(
                    label: 'Fragile Handling Protective Surcharge',
                    amount: 300.0,
                  ),
                ],
                SizedBox(height: 12.h),
                const Divider(height: 1),
                SizedBox(height: 12.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Gross Total Fare',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '₦${pricing.totalFare.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 16.h),

          // Revenue Split Breakdown (80% Driver, 20% Platform)
          Text(
            'Revenue Split Model',
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 8.h),

          Row(
            children: [
              Expanded(
                child: Container(
                  padding: EdgeInsets.all(14.w),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.two_wheeler,
                              size: 16.w, color: Colors.green.shade800),
                          SizedBox(width: 4.w),
                          Text(
                            'Driver (80%)',
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade900,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 6.h),
                      Text(
                        '₦${driverEarnings.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade900,
                        ),
                      ),
                      Text(
                        'Net Courier Earnings',
                        style: TextStyle(
                          fontSize: 10.sp,
                          color: Colors.green.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Container(
                  padding: EdgeInsets.all(14.w),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade50,
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: Colors.indigo.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.business,
                              size: 16.w, color: Colors.indigo.shade800),
                          SizedBox(width: 4.w),
                          Text(
                            'Platform (20%)',
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.indigo.shade900,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 6.h),
                      Text(
                        '₦${platformCommission.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo.shade900,
                        ),
                      ),
                      Text(
                        'Operations Fee',
                        style: TextStyle(
                          fontSize: 10.sp,
                          color: Colors.indigo.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),

          // Payment Status & Method Details
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Payment Method',
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      pricing.paymentMethod.label,
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 4.h,
                  ),
                  decoration: BoxDecoration(
                    color: pricing.isPaid
                        ? Colors.green.shade100
                        : Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Text(
                    pricing.isPaid ? 'PAID & SETTLED' : 'UNPAID / PENDING',
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.bold,
                      color: pricing.isPaid
                          ? Colors.green.shade900
                          : Colors.amber.shade900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 20.h),

          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 14.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
            child: const Text('Close Breakdown'),
          ),
        ],
      ),
    );
  }

  Widget _buildRow({required String label, required double amount}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13.sp,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Text(
          '₦${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
