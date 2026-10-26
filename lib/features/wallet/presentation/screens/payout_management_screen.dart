import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../core/presentation/styles/app_colors.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/payout_request.dart';
import '../../domain/value_objects/payout_status.dart';
import '../providers/wallet_providers.dart';

/// Centralized Payout Management Console for Operations & Finance Admins.
/// Allows approving, settling, or rejecting driver withdrawal requests.
class PayoutManagementScreen extends StatefulHookConsumerWidget {
  const PayoutManagementScreen({super.key});

  @override
  ConsumerState<PayoutManagementScreen> createState() =>
      _PayoutManagementScreenState();
}

class _PayoutManagementScreenState
    extends ConsumerState<PayoutManagementScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final payoutsAsync = ref.watch(allPayoutRequestsStreamProvider);
    final selectedFilter = ref.watch(payoutStatusFilterProvider);
    final currentAdmin = ref.watch(currentUserProfileProvider).value;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Driver Payout Settlements',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Filter & Search Header
          Container(
            color: AppColors.surface,
            padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 12.h),
            child: Column(
              children: [
                TextField(
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val.trim().toLowerCase();
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search driver name, bank, or account...',
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
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('All Requests', null, selectedFilter),
                      SizedBox(width: 8.w),
                      _buildFilterChip(
                        'Pending Review',
                        PayoutStatus.pending,
                        selectedFilter,
                      ),
                      SizedBox(width: 8.w),
                      _buildFilterChip(
                        'Settled / Paid',
                        PayoutStatus.settled,
                        selectedFilter,
                      ),
                      SizedBox(width: 8.w),
                      _buildFilterChip(
                        'Rejected',
                        PayoutStatus.rejected,
                        selectedFilter,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Payouts List
          Expanded(
            child: payoutsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Text('Error loading payouts: $err'),
              ),
              data: (payouts) {
                final filtered = payouts.where((p) {
                  if (_searchQuery.isNotEmpty) {
                    final nameMatch =
                        p.driverName.toLowerCase().contains(_searchQuery);
                    final bankMatch =
                        p.bankName.toLowerCase().contains(_searchQuery);
                    final accountMatch =
                        p.accountNumber.contains(_searchQuery);
                    if (!nameMatch && !bankMatch && !accountMatch) {
                      return false;
                    }
                  }
                  return true;
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.account_balance_outlined,
                          size: 64.w,
                          color: AppColors.textSecondary.withValues(alpha: 0.5),
                        ),
                        SizedBox(height: 12.h),
                        Text(
                          'No payout requests in this view.',
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
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => SizedBox(height: 12.h),
                  itemBuilder: (ctx, idx) {
                    final payout = filtered[idx];
                    return _buildPayoutCard(payout, currentAdmin?.uid ?? 'admin');
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    String label,
    PayoutStatus? status,
    PayoutStatus? activeStatus,
  ) {
    final isSelected = activeStatus == status;
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
        ref.read(payoutStatusFilterProvider.notifier).state = status;
      },
    );
  }

  Widget _buildPayoutCard(PayoutRequest payout, String adminId) {
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '₦${payout.amount.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              _buildStatusPill(payout.status),
            ],
          ),
          SizedBox(height: 8.h),

          // Driver Details
          Row(
            children: [
              const Icon(Icons.person, size: 16, color: AppColors.textSecondary),
              SizedBox(width: 6.w),
              Text(
                '${payout.driverName} (${payout.driverPhone})',
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),

          // Destination Bank Details
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Row(
              children: [
                const Icon(Icons.account_balance,
                    size: 20, color: AppColors.primary),
                SizedBox(width: 10.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        payout.bankName,
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        '${payout.accountNumber} • ${payout.accountName}',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 10.h),

          // Audit Info
          Text(
            'Requested: ${payout.createdAt.day}/${payout.createdAt.month}/${payout.createdAt.year} ${payout.createdAt.hour.toString().padLeft(2, '0')}:${payout.createdAt.minute.toString().padLeft(2, '0')}',
            style: TextStyle(fontSize: 11.sp, color: AppColors.textSecondary),
          ),
          if (payout.transactionRef != null) ...[
            SizedBox(height: 2.h),
            Text(
              'Bank Ref: ${payout.transactionRef}',
              style: TextStyle(
                fontSize: 11.sp,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade800,
              ),
            ),
          ],
          if (payout.rejectionReason != null) ...[
            SizedBox(height: 2.h),
            Text(
              'Rejection Reason: ${payout.rejectionReason}',
              style: TextStyle(
                fontSize: 11.sp,
                color: Colors.red.shade800,
              ),
            ),
          ],

          // Actions for pending payouts
          if (payout.status == PayoutStatus.pending) ...[
            SizedBox(height: 14.h),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _showRejectDialog(payout, adminId),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                    ),
                    child: const Text('Reject & Refund'),
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _showApproveDialog(payout, adminId),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                    ),
                    child: const Text('Mark Settled'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusPill(PayoutStatus status) {
    Color bg;
    Color fg;

    switch (status) {
      case PayoutStatus.pending:
        bg = Colors.amber.shade100;
        fg = Colors.amber.shade900;
        break;
      case PayoutStatus.approved:
      case PayoutStatus.settled:
        bg = Colors.green.shade100;
        fg = Colors.green.shade900;
        break;
      case PayoutStatus.rejected:
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
          fontWeight: FontWeight.bold,
          color: fg,
        ),
      ),
    );
  }

  void _showApproveDialog(PayoutRequest payout, String adminId) {
    final refController = TextEditingController(
      text: 'NIP-${DateTime.now().millisecondsSinceEpoch}',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Payout Settlement'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Confirm that ₦${payout.amount.toStringAsFixed(2)} was transferred to ${payout.accountName} (${payout.bankName}).',
            ),
            SizedBox(height: 12.h),
            TextField(
              controller: refController,
              decoration: const InputDecoration(
                labelText: 'Bank Transfer Reference / Session ID',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final service = ref.read(walletRemoteServiceProvider);
              final result = await service.approvePayout(
                payoutId: payout.id,
                adminId: adminId,
                transactionRef: refController.text.trim(),
              );

              if (mounted) {
                result.fold(
                  (failure) => ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(failure.message),
                      backgroundColor: Colors.red,
                    ),
                  ),
                  (_) => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Payout marked as settled successfully!'),
                      backgroundColor: Colors.green,
                    ),
                  ),
                );
              }
            },
            child: const Text('Confirm Settlement'),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(PayoutRequest payout, String adminId) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Payout & Refund Driver'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'The requested ₦${payout.amount.toStringAsFixed(2)} will be immediately reversed back to ${payout.driverName}\'s digital wallet balance.',
            ),
            SizedBox(height: 12.h),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason for Rejection (e.g. Invalid account details)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) return;

              Navigator.pop(ctx);
              final service = ref.read(walletRemoteServiceProvider);
              final result = await service.rejectPayout(
                payoutId: payout.id,
                adminId: adminId,
                reason: reason,
              );

              if (mounted) {
                result.fold(
                  (failure) => ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(failure.message),
                      backgroundColor: Colors.red,
                    ),
                  ),
                  (_) => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Payout rejected and funds refunded to driver.'),
                      backgroundColor: Colors.orange,
                    ),
                  ),
                );
              }
            },
            child: const Text('Reject & Refund'),
          ),
        ],
      ),
    );
  }
}
