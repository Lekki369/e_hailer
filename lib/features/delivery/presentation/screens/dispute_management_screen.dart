import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/presentation/styles/app_colors.dart';
import '../../../../core/presentation/widgets/app_snackbar.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/delivery_dispute.dart';
import '../../domain/value_objects/dispute_status.dart';
import '../providers/dispute_providers.dart';

/// Admin & Operations Console for Dispute Arbitration, Customer Refunds, and Hub Returns
class DisputeManagementScreen extends HookConsumerWidget {
  const DisputeManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final disputesAsync = ref.watch(allDisputesStreamProvider);
    final selectedFilter = useState<DisputeStatus?>(null);
    final searchQuery = useState<String>('');
    final searchController = useTextEditingController();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Disputes & Incident Management'),
      ),
      body: disputesAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.secondary),
        ),
        error: (error, _) => Center(
          child: Text(
            'Error loading disputes: $error',
            style: const TextStyle(color: AppColors.error),
          ),
        ),
        data: (allDisputes) {
          // Compute summary metrics
          final totalCount = allDisputes.length;
          final pendingCount =
              allDisputes.where((d) => d.status.isPending).length;
          final refundedCount = allDisputes
              .where((d) => d.status == DisputeStatus.resolvedRefund)
              .length;
          final returnedCount = allDisputes
              .where((d) => d.status == DisputeStatus.resolvedReturn)
              .length;

          // Apply filters
          final filtered = allDisputes.where((d) {
            final matchesFilter =
                selectedFilter.value == null || d.status == selectedFilter.value;
            final q = searchQuery.value.trim().toLowerCase();
            final matchesSearch = q.isEmpty ||
                d.trackingNumber.toLowerCase().contains(q) ||
                d.claimantName.toLowerCase().contains(q) ||
                d.claimantPhone.toLowerCase().contains(q) ||
                d.description.toLowerCase().contains(q);
            return matchesFilter && matchesSearch;
          }).toList();

          return Column(
            children: [
              // 1. KPI Metric Bar
              Container(
                color: Colors.white,
                padding:
                    EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                child: Row(
                  children: [
                    _buildMetricChip('Total', totalCount, AppColors.primary),
                    SizedBox(width: 8.w),
                    _buildMetricChip(
                        'Pending Review', pendingCount, AppColors.warning),
                    SizedBox(width: 8.w),
                    _buildMetricChip(
                        'Refunded', refundedCount, AppColors.success),
                    SizedBox(width: 8.w),
                    _buildMetricChip(
                        'Returned to Hub', returnedCount, AppColors.info),
                  ],
                ),
              ),

              // 2. Search & Tab Filter Row
              Container(
                color: Colors.white,
                padding:
                    EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                child: Column(
                  children: [
                    // Search Bar
                    TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        hintText: 'Search by Waybill, Claimant, or Phone...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  searchController.clear();
                                  searchQuery.value = '';
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: AppColors.background,
                        contentPadding: EdgeInsets.zero,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.r),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (val) => searchQuery.value = val,
                    ),
                    SizedBox(height: 10.h),

                    // Filter Chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterTab(
                            label: 'All (${allDisputes.length})',
                            isSelected: selectedFilter.value == null,
                            onTap: () => selectedFilter.value = null,
                          ),
                          SizedBox(width: 6.w),
                          _buildFilterTab(
                            label: 'Open ($pendingCount)',
                            isSelected:
                                selectedFilter.value == DisputeStatus.open,
                            onTap: () => selectedFilter.value =
                                DisputeStatus.open,
                          ),
                          SizedBox(width: 6.w),
                          _buildFilterTab(
                            label: 'Refunded ($refundedCount)',
                            isSelected: selectedFilter.value ==
                                DisputeStatus.resolvedRefund,
                            onTap: () => selectedFilter.value =
                                DisputeStatus.resolvedRefund,
                          ),
                          SizedBox(width: 6.w),
                          _buildFilterTab(
                            label: 'Returned ($returnedCount)',
                            isSelected: selectedFilter.value ==
                                DisputeStatus.resolvedReturn,
                            onTap: () => selectedFilter.value =
                                DisputeStatus.resolvedReturn,
                          ),
                          SizedBox(width: 6.w),
                          _buildFilterTab(
                            label: 'Dismissed',
                            isSelected:
                                selectedFilter.value == DisputeStatus.rejected,
                            onTap: () => selectedFilter.value =
                                DisputeStatus.rejected,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // 3. Dispute Ticket List
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle_outline_rounded,
                                size: 54.r, color: AppColors.success),
                            SizedBox(height: 12.h),
                            Text(
                              'No disputes in this view',
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              'All customer claims and driver exception reports are cleared.',
                              style: TextStyle(
                                fontSize: 13.sp,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: EdgeInsets.all(16.r),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => SizedBox(height: 12.h),
                        itemBuilder: (context, index) {
                          final dispute = filtered[index];
                          return _buildDisputeCard(context, ref, dispute);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMetricChip(String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 6.w),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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

  Widget _buildFilterTab({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.background,
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.divider,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.sp,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildDisputeCard(
    BuildContext context,
    WidgetRef ref,
    DeliveryDispute dispute,
  ) {
    final isPending = dispute.status.isPending;
    final isRefunded = dispute.status == DisputeStatus.resolvedRefund;
    final isReturned = dispute.status == DisputeStatus.resolvedReturn;

    final badgeColor = isPending
        ? AppColors.warning
        : isRefunded
            ? AppColors.success
            : isReturned
                ? AppColors.info
                : AppColors.error;

    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Waybill and Status Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    dispute.trackingNumber,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  SizedBox(width: 6.w),
                  InkWell(
                    onTap: () {
                      Clipboard.setData(
                          ClipboardData(text: dispute.trackingNumber));
                      AppSnackBar.showSuccess(context, 'Waybill copied!');
                    },
                    child: Icon(Icons.copy,
                        size: 14.r, color: AppColors.textSecondary),
                  ),
                ],
              ),
              Container(
                padding:
                    EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6.r),
                ),
                child: Text(
                  dispute.status.label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.bold,
                    color: badgeColor,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),

          // Category Badge
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(6.r),
              border: Border.all(color: AppColors.divider),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  dispute.claimantRole == 'driver'
                      ? Icons.directions_bike_rounded
                      : Icons.person_rounded,
                  size: 14.r,
                  color: AppColors.textSecondary,
                ),
                SizedBox(width: 6.w),
                Text(
                  dispute.category.label,
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 10.h),

          // Description
          Text(
            dispute.description,
            style: TextStyle(
              fontSize: 13.sp,
              color: AppColors.textPrimary,
              height: 1.3,
            ),
          ),

          if (dispute.evidenceNotes != null) ...[
            SizedBox(height: 6.h),
            Container(
              padding: EdgeInsets.all(8.r),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Text(
                'Notes: ${dispute.evidenceNotes}',
                style: TextStyle(
                  fontSize: 11.sp,
                  color: AppColors.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
          SizedBox(height: 10.h),

          // Claimant & Timestamp Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Claimant: ${dispute.claimantName} (${dispute.claimantRole.toUpperCase()})',
                style: TextStyle(
                  fontSize: 11.sp,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                DateFormat('MMM d, h:mm a').format(dispute.createdAt),
                style: TextStyle(
                  fontSize: 11.sp,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),

          // Resolution Result Banner (if resolved)
          if (!isPending) ...[
            SizedBox(height: 10.h),
            Container(
              padding: EdgeInsets.all(10.r),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(color: badgeColor.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Icon(
                    isRefunded
                        ? Icons.currency_exchange_rounded
                        : isReturned
                            ? Icons.assignment_return_rounded
                            : Icons.cancel_outlined,
                    size: 18.r,
                    color: badgeColor,
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      isRefunded
                          ? 'Customer Refunded ₦${dispute.refundAmount?.toStringAsFixed(2) ?? '0.00'} • ${dispute.resolutionNotes ?? ''}'
                          : isReturned
                              ? 'Returned to Hub • Code: ${dispute.returnTrackingNumber ?? 'N/A'}'
                              : 'Dismissed: ${dispute.resolutionNotes ?? 'No reason stated'}',
                      style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w600,
                        color: badgeColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Arbitration Action Button (for Pending tickets)
          if (isPending) ...[
            SizedBox(height: 12.h),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding:
                      EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
                icon: const Icon(Icons.gavel_rounded, size: 16),
                label: Text(
                  'Arbitrate & Resolve',
                  style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  _showArbitrationModal(context, ref, dispute);
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showArbitrationModal(
    BuildContext context,
    WidgetRef ref,
    DeliveryDispute dispute,
  ) {
    final notesController = TextEditingController();
    final refundAmountController = TextEditingController();
    final returnTrackingController = TextEditingController(
      text: 'RET-${dispute.trackingNumber}',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (modalContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20.w,
            right: 20.w,
            top: 20.h,
            bottom: MediaQuery.of(modalContext).viewInsets.bottom + 20.h,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              SizedBox(height: 16.h),
              Text(
                'Arbitrate Dispute #${dispute.trackingNumber}',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                'Claimant: ${dispute.claimantName} • Issue: ${dispute.category.label}',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: AppColors.textSecondary,
                ),
              ),
              SizedBox(height: 16.h),

              TextField(
                controller: notesController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Arbitration / Investigation Notes',
                  hintText: 'Enter resolution details or findings...',
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.r),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              SizedBox(height: 12.h),

              TextField(
                controller: refundAmountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Refund Amount in NGN (if refunding customer)',
                  hintText: 'e.g. 2500',
                  prefixText: '₦ ',
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.r),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              SizedBox(height: 20.h),

              // Three Action Choices: Refund vs Return to Hub vs Dismiss
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                      ),
                      onPressed: () async {
                        final notes = notesController.text.trim();
                        final admin = ref.read(currentUserProfileProvider).value;
                        Navigator.of(modalContext).pop();
                        await ref
                            .read(disputeRemoteServiceProvider)
                            .resolveDispute(
                              disputeId: dispute.id,
                              orderId: dispute.orderId,
                              status: DisputeStatus.rejected,
                              resolvedBy: admin?.fullName ?? 'Admin Ops',
                              resolutionNotes: notes.isNotEmpty
                                  ? notes
                                  : 'Claim dismissed after operational review.',
                            );
                      },
                      child: const Text('Dismiss Claim'),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.info,
                        side: const BorderSide(color: AppColors.info),
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                      ),
                      onPressed: () async {
                        final notes = notesController.text.trim();
                        final admin = ref.read(currentUserProfileProvider).value;
                        final returnTracking =
                            returnTrackingController.text.trim();
                        Navigator.of(modalContext).pop();
                        await ref
                            .read(disputeRemoteServiceProvider)
                            .resolveDispute(
                              disputeId: dispute.id,
                              orderId: dispute.orderId,
                              status: DisputeStatus.resolvedReturn,
                              resolvedBy: admin?.fullName ?? 'Admin Ops',
                              resolutionNotes: notes.isNotEmpty
                                  ? notes
                                  : 'Shipment authorized for return to sorting hub.',
                              returnTrackingNumber: returnTracking,
                            );
                      },
                      child: const Text('Return to Hub'),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                      ),
                      onPressed: () async {
                        final amount = double.tryParse(
                                refundAmountController.text.trim()) ??
                            0.0;
                        final notes = notesController.text.trim();
                        final admin = ref.read(currentUserProfileProvider).value;
                        Navigator.of(modalContext).pop();

                        await ref
                            .read(disputeRemoteServiceProvider)
                            .resolveDispute(
                              disputeId: dispute.id,
                              orderId: dispute.orderId,
                              status: DisputeStatus.resolvedRefund,
                              resolvedBy: admin?.fullName ?? 'Admin Ops',
                              resolutionNotes: notes.isNotEmpty
                                  ? notes
                                  : 'Approved customer wallet refund.',
                              refundAmount: amount,
                              customerId: dispute.claimantId,
                            );
                      },
                      child: const Text('Refund'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
