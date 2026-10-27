import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../core/presentation/styles/app_colors.dart';
import '../../../../core/presentation/widgets/app_snackbar.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../auth/domain/user_entity.dart';
import '../../domain/entities/delivery_dispute.dart';
import '../../domain/entities/delivery_order.dart';
import '../../domain/value_objects/dispute_category.dart';
import '../providers/dispute_providers.dart';

/// Modal for Drivers to report delivery exceptions (unreachable recipient, wrong address, refused package)
class ReportDeliveryIssueModal extends ConsumerStatefulWidget {
  final DeliveryOrder order;
  final UserEntity driver;

  const ReportDeliveryIssueModal({
    super.key,
    required this.order,
    required this.driver,
  });

  static Future<void> show(
    BuildContext context,
    DeliveryOrder order,
    UserEntity driver,
  ) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (_) => ReportDeliveryIssueModal(order: order, driver: driver),
    );
  }

  @override
  ConsumerState<ReportDeliveryIssueModal> createState() =>
      _ReportDeliveryIssueModalState();
}

class _ReportDeliveryIssueModalState
    extends ConsumerState<ReportDeliveryIssueModal> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _attemptsController = TextEditingController();

  DisputeCategory _selectedCategory = DisputeCategory.unreachableRecipient;
  bool _isSubmitting = false;

  final List<DisputeCategory> _driverCategories = [
    DisputeCategory.unreachableRecipient,
    DisputeCategory.wrongAddress,
    DisputeCategory.packageRefused,
    DisputeCategory.damagedItem,
    DisputeCategory.other,
  ];

  @override
  void dispose() {
    _descriptionController.dispose();
    _attemptsController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final dispute = DeliveryDispute(
      id: '',
      orderId: widget.order.id,
      trackingNumber: widget.order.trackingNumber,
      claimantId: widget.driver.uid,
      claimantName: widget.driver.fullName,
      claimantRole: 'driver',
      claimantPhone: widget.driver.phone,
      category: _selectedCategory,
      description: _descriptionController.text.trim(),
      evidenceNotes: _attemptsController.text.trim().isNotEmpty
          ? 'Call Attempts: ${_attemptsController.text.trim()}'
          : null,
      createdAt: DateTime.now(),
    );

    final result =
        await ref.read(disputeRemoteServiceProvider).fileDispute(dispute);

    setState(() => _isSubmitting = false);

    if (!mounted) return;

    result.fold(
      (failure) {
        AppSnackBar.showError(context, failure.message);
      },
      (_) {
        Navigator.of(context).pop();
        AppSnackBar.showWarning(
          context,
          'Delivery issue logged. Shipment flagged for hub return/review.',
        );
        context.go(AppRoutes.driverDashboardPath);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20.w,
        right: 20.w,
        top: 20.h,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20.h,
      ),
      child: Form(
        key: _formKey,
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
            Row(
              children: [
                const Icon(Icons.report_problem_rounded,
                    color: AppColors.error),
                SizedBox(width: 10.w),
                Text(
                  'Report Delivery Failure',
                  style: TextStyle(
                    fontSize: 17.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            SizedBox(height: 4.h),
            Text(
              'Order #${widget.order.trackingNumber} • Waybill Consignment',
              style: TextStyle(
                fontSize: 12.sp,
                color: AppColors.textSecondary,
              ),
            ),
            SizedBox(height: 16.h),

            // Category Dropdown
            DropdownButtonFormField<DisputeCategory>(
              initialValue: _selectedCategory,
              decoration: InputDecoration(
                labelText: 'Reason for Incomplete Delivery',
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: BorderSide.none,
                ),
              ),
              items: _driverCategories.map((cat) {
                return DropdownMenuItem(
                  value: cat,
                  child: Text(
                    cat.label,
                    style: TextStyle(fontSize: 13.sp),
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedCategory = val);
              },
            ),
            SizedBox(height: 12.h),

            // Call attempts note
            TextFormField(
              controller: _attemptsController,
              decoration: InputDecoration(
                labelText: 'Contact Attempts (Optional)',
                hintText: 'e.g. Called recipient 3 times at 2:15 PM & 2:30 PM',
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            SizedBox(height: 12.h),

            // Description
            TextFormField(
              controller: _descriptionController,
              maxLines: 3,
              validator: (val) {
                if (val == null || val.trim().length < 5) {
                  return 'Please provide operational details (min 5 chars)';
                }
                return null;
              },
              decoration: InputDecoration(
                labelText: 'Detailed Explanation & Observations',
                hintText: 'Describe physical location, gate accessibility, etc.',
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            SizedBox(height: 20.h),

            // Submit Button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 14.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
              onPressed: _isSubmitting ? null : _submitReport,
              child: _isSubmitting
                  ? SizedBox(
                      height: 20.h,
                      width: 20.h,
                      child: const CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      'Log Issue & Return Consignment',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
