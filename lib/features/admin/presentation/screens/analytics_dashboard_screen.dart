import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../core/presentation/styles/app_colors.dart';
import '../../../delivery/domain/value_objects/delivery_type.dart';
import '../../domain/entities/operations_analytics.dart';
import '../providers/analytics_providers.dart';

/// Comprehensive Executive & Operations Reporting Dashboard for Fleet & Revenue Analytics
class AnalyticsDashboardScreen extends HookConsumerWidget {
  const AnalyticsDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analyticsAsync = ref.watch(operationsAnalyticsProvider);
    final selectedRange = ref.watch(analyticsTimeRangeProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Fleet Operations Analytics'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Time Horizon Filter Tabs
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: AnalyticsTimeRange.values.map((range) {
                  final isSelected = selectedRange == range;
                  return Padding(
                    padding: EdgeInsets.only(right: 8.w),
                    child: ChoiceChip(
                      label: Text(range.label),
                      selected: isSelected,
                      selectedColor: AppColors.primary,
                      backgroundColor: Colors.white,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : AppColors.textPrimary,
                        fontSize: 12.sp,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      onSelected: (_) {
                        ref.read(analyticsTimeRangeProvider.notifier).state =
                            range;
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            SizedBox(height: 16.h),

            analyticsAsync.when(
              loading: () => Container(
                height: 350.h,
                alignment: Alignment.center,
                child: const CircularProgressIndicator(
                  color: AppColors.secondary,
                ),
              ),
              error: (err, _) => Center(
                child: Text(
                  'Failed to compute analytics: $err',
                  style: const TextStyle(color: AppColors.error),
                ),
              ),
              data: (data) => _buildAnalyticsBody(context, data),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticsBody(BuildContext context, OperationsAnalytics data) {
    final totalPaymentOrders = data.codOrdersCount + data.digitalOrdersCount;
    final codPercentage = totalPaymentOrders > 0
        ? (data.codOrdersCount / totalPaymentOrders) * 100
        : 0.0;
    final digitalPercentage = totalPaymentOrders > 0
        ? (data.digitalOrdersCount / totalPaymentOrders) * 100
        : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Revenue & Financial Engine Breakdown
        Container(
          padding: EdgeInsets.all(20.r),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.primaryLight],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18.r),
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
                    'GROSS MERCHANDISE VALUE (GMV)',
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                      color: Colors.white70,
                    ),
                  ),
                  Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Text(
                      '80/20 Split',
                      style: TextStyle(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.secondaryLight,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 6.h),
              Text(
                '₦${data.grossGmvNgn.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 26.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 18.h),

              Row(
                children: [
                  _buildFinancialStat(
                    'Platform Revenue (20%)',
                    '₦${data.platformCommissionNgn.toStringAsFixed(2)}',
                    AppColors.secondaryLight,
                  ),
                  _buildFinancialStat(
                    'Driver Payouts (80%)',
                    '₦${data.driverPayoutsNgn.toStringAsFixed(2)}',
                    AppColors.success,
                  ),
                  _buildFinancialStat(
                    'Avg Order Value',
                    '₦${data.averageOrderValueNgn.toStringAsFixed(0)}',
                    Colors.white,
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: 16.h),

        // 2. Payment Modality Breakdown (COD vs Digital Wallet)
        Container(
          padding: EdgeInsets.all(16.r),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Settlement Modality Split',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    '${data.totalOrders} Total Orders',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12.h),

              // Segmented progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(8.r),
                child: SizedBox(
                  height: 10.h,
                  child: Row(
                    children: [
                      Expanded(
                        flex: (codPercentage * 10).round().clamp(1, 1000),
                        child: Container(color: AppColors.secondary),
                      ),
                      Expanded(
                        flex: (digitalPercentage * 10).round().clamp(1, 1000),
                        child: Container(color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 12.h),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildLegendItem(
                    color: AppColors.secondary,
                    label: 'Cash on Delivery (COD)',
                    value:
                        '${data.codOrdersCount} (${codPercentage.toStringAsFixed(1)}%)',
                  ),
                  _buildLegendItem(
                    color: AppColors.primary,
                    label: 'Prepaid Digital Wallet',
                    value:
                        '${data.digitalOrdersCount} (${digitalPercentage.toStringAsFixed(1)}%)',
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: 16.h),

        // 3. Operational Fulfillment Funnel & Reliability
        Container(
          padding: EdgeInsets.all(16.r),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Fulfillment Reliability & Volume',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 14.h),

              Row(
                children: [
                  _buildFunnelCard(
                    title: 'Completed',
                    count: data.completedOrders,
                    percentage: '${data.completionRate.toStringAsFixed(1)}%',
                    color: AppColors.success,
                    icon: Icons.check_circle_rounded,
                  ),
                  SizedBox(width: 8.w),
                  _buildFunnelCard(
                    title: 'In Transit',
                    count: data.inTransitOrders,
                    percentage: 'Active',
                    color: AppColors.info,
                    icon: Icons.navigation_rounded,
                  ),
                  SizedBox(width: 8.w),
                  _buildFunnelCard(
                    title: 'Failed / Cancelled',
                    count: data.failedOrCancelledOrders,
                    percentage: '${data.failureRate.toStringAsFixed(1)}%',
                    color: AppColors.error,
                    icon: Icons.cancel_rounded,
                  ),
                ],
              ),
              SizedBox(height: 14.h),
              Divider(color: AppColors.divider.withValues(alpha: 0.6)),
              SizedBox(height: 8.h),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.scale_rounded,
                          size: 18.r, color: AppColors.textSecondary),
                      SizedBox(width: 8.w),
                      Text(
                        'Total Consignment Freight Transported',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${data.totalCargoVolumeKg.toStringAsFixed(1)} kg',
                    style: TextStyle(
                      fontSize: 14.sp,
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

        // 4. SLA & Delivery Speed Efficiency
        Container(
          padding: EdgeInsets.all(16.r),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SLA & Delivery Speed Efficiency',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 14.h),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.all(12.w),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.timer_outlined,
                                  size: 16.w, color: Colors.green.shade800),
                              SizedBox(width: 4.w),
                              Text(
                                'On-Time Rate',
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green.shade900,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            '${data.onTimeRate.toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.all(12.w),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.speed_rounded,
                                  size: 16.w, color: Colors.blue.shade800),
                              SizedBox(width: 4.w),
                              Text(
                                'Avg Delivery Time',
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue.shade900,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            data.averageDeliveryTimeMinutes > 0
                                ? '${data.averageDeliveryTimeMinutes.toStringAsFixed(0)} mins'
                                : 'N/A',
                            style: TextStyle(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: 16.h),

        // 5. Active Regional Dispatch Zones
        if (data.zoneBreakdown.isNotEmpty) ...[
          Container(
            padding: EdgeInsets.all(16.r),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Top Regional Dispatch Zones',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 12.h),
                Wrap(
                  spacing: 8.w,
                  runSpacing: 8.h,
                  children: data.zoneBreakdown.entries.map((entry) {
                    return Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10.w,
                        vertical: 6.h,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: Text(
                        '${entry.key}: ${entry.value} orders',
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          SizedBox(height: 16.h),
        ],

        // 6. Vehicle Fleet Allocation
        Container(
          padding: EdgeInsets.all(16.r),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Vehicle Fleet Utilization',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 12.h),

              Row(
                children: [
                  _buildVehicleTile(
                    'Motorcycle',
                    data.vehicleBreakdown[VehicleType.bike] ?? 0,
                    data.totalOrders,
                    Icons.two_wheeler_rounded,
                  ),
                  SizedBox(width: 8.w),
                  _buildVehicleTile(
                    'Sedan / Car',
                    data.vehicleBreakdown[VehicleType.car] ?? 0,
                    data.totalOrders,
                    Icons.directions_car_rounded,
                  ),
                  SizedBox(width: 8.w),
                  _buildVehicleTile(
                    'Cargo Van',
                    data.vehicleBreakdown[VehicleType.van] ?? 0,
                    data.totalOrders,
                    Icons.airport_shuttle_rounded,
                  ),
                  SizedBox(width: 8.w),
                  _buildVehicleTile(
                    'Heavy Truck',
                    data.vehicleBreakdown[VehicleType.truck] ?? 0,
                    data.totalOrders,
                    Icons.local_shipping_rounded,
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: 16.h),

        // 5. Driver Performance Leaderboard
        Container(
          padding: EdgeInsets.all(16.r),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Top Fleet Couriers Leaderboard',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Icon(Icons.emoji_events_rounded,
                      color: AppColors.warning, size: 20),
                ],
              ),
              SizedBox(height: 12.h),

              if (data.driverLeaderboard.isEmpty)
                Container(
                  padding: EdgeInsets.all(20.r),
                  alignment: Alignment.center,
                  child: Text(
                    'No completed driver deliveries in this timeframe.',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: AppColors.textSecondary,
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: data.driverLeaderboard.length,
                  separatorBuilder: (_, __) =>
                      Divider(color: AppColors.divider.withValues(alpha: 0.5)),
                  itemBuilder: (context, index) {
                    final item = data.driverLeaderboard[index];
                    final rankMedal = index == 0
                        ? '🥇'
                        : index == 1
                            ? '🥈'
                            : index == 2
                                ? '🥉'
                                : '#${index + 1}';

                    return Row(
                      children: [
                        Text(
                          rankMedal,
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.driverName,
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              SizedBox(height: 2.h),
                              Text(
                                '${item.vehicleType.label} • ${item.phone}',
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${item.completedDeliveries} Trips',
                              style: TextStyle(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                            SizedBox(height: 2.h),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star,
                                    size: 13, color: AppColors.warning),
                                SizedBox(width: 3.w),
                                Text(
                                  item.rating.toStringAsFixed(1),
                                  style: TextStyle(
                                    fontSize: 11.sp,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
            ],
          ),
        ),
        SizedBox(height: 24.h),
      ],
    );
  }

  Widget _buildFinancialStat(String label, String value, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.sp,
              color: Colors.white70,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            value,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem({
    required Color color,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          width: 10.r,
          height: 10.r,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2.r),
          ),
        ),
        SizedBox(width: 6.w),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10.sp,
                color: AppColors.textSecondary,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFunnelCard({
    required String title,
    required int count,
    required String percentage,
    required Color color,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 8.w),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18.r, color: color),
            SizedBox(height: 4.h),
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.sp,
                color: AppColors.textSecondary,
              ),
            ),
            SizedBox(height: 2.h),
            Text(
              percentage,
              style: TextStyle(
                fontSize: 10.sp,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleTile(
    String label,
    int count,
    int total,
    IconData icon,
  ) {
    final share = total > 0 ? (count / total) * 100 : 0.0;
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 4.w),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20.r, color: AppColors.primary),
            SizedBox(height: 4.h),
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9.sp,
                color: AppColors.textSecondary,
              ),
            ),
            SizedBox(height: 2.h),
            Text(
              '${share.toStringAsFixed(0)}%',
              style: TextStyle(
                fontSize: 10.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.secondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
