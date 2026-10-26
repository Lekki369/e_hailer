import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../core/presentation/styles/app_colors.dart';
import '../../../auth/domain/user_entity.dart';
import '../../domain/entities/delivery_dispute.dart';
import '../../domain/entities/delivery_order.dart';
import '../../domain/value_objects/dispute_category.dart';
import '../providers/dispute_providers.dart';

/// Modal for Customers & Recipients to file damage, loss, or service disputes
class FileDisputeModal extends ConsumerStatefulWidget {
  final DeliveryOrder order;
  final UserEntity? currentUser;

  const FileDisputeModal({
    super.key,
    required this.order,
    this.currentUser,
  });

  static Future<void> show(
    BuildContext context,
    DeliveryOrder order, {
    UserEntity? currentUser,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (_) => FileDisputeModal(order: order, currentUser: currentUser),
    );
  }

  @override
  ConsumerState<FileDisputeModal> createState() => _FileDisputeModalState();
}

class _FileDisputeModalState extends ConsumerState<FileDisputeModal> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  final _descriptionController = TextEditingController();

  DisputeCategory _selectedCategory = DisputeCategory.damagedItem;
  bool _isSubmitting = false;

  final List<DisputeCategory> _customerCategories = [
    DisputeCategory.damagedItem,
    DisputeCategory.missingItem,
    DisputeCategory.fareDispute,
    DisputeCategory.driverMisconduct,
    DisputeCategory.other,
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.currentUser?.fullName ?? widget.order.customerName,
    );
    _phoneController = TextEditingController(
      text: widget.currentUser?.phone ?? widget.order.customerPhone,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submitDispute() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final dispute = DeliveryDispute(
      id: '',
      orderId: widget.order.id,
      trackingNumber: widget.order.trackingNumber,
      claimantId: widget.currentUser?.uid ?? widget.order.customerId,
      claimantName: _nameController.text.trim(),
      claimantRole: 'customer',
      claimantPhone: _phoneController.text.trim(),
      category: _selectedCategory,
      description: _descriptionController.text.trim(),
      createdAt: DateTime.now(),
    );

    final result =
        await ref.read(disputeRemoteServiceProvider).fileDispute(dispute);

    setState(() => _isSubmitting = false);

    if (!mounted) return;

    result.fold(
      (failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            content: Text(failure.message),
          ),
        );
      },
      (ticket) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.success,
            content: Text(
              'Dispute submitted successfully! Ticket #${ticket.id.substring(0, 6.clamp(0, ticket.id.length)).toUpperCase()}',
            ),
          ),
        );
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
                const Icon(Icons.shield_outlined, color: AppColors.secondary),
                SizedBox(width: 10.w),
                Text(
                  'Submit Claim or Dispute',
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
              'Shipment #${widget.order.trackingNumber}',
              style: TextStyle(
                fontSize: 12.sp,
                color: AppColors.textSecondary,
              ),
            ),
            SizedBox(height: 16.h),

            // Dispute Category
            DropdownButtonFormField<DisputeCategory>(
              initialValue: _selectedCategory,
              decoration: InputDecoration(
                labelText: 'Nature of Issue',
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: BorderSide.none,
                ),
              ),
              items: _customerCategories.map((cat) {
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

            // Claimant Name & Phone
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _nameController,
                    validator: (val) =>
                        val == null || val.trim().isEmpty ? 'Required' : null,
                    decoration: InputDecoration(
                      labelText: 'Your Name',
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: TextFormField(
                    controller: _phoneController,
                    validator: (val) =>
                        val == null || val.trim().isEmpty ? 'Required' : null,
                    decoration: InputDecoration(
                      labelText: 'Contact Phone',
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),

            // Description
            TextFormField(
              controller: _descriptionController,
              maxLines: 3,
              validator: (val) {
                if (val == null || val.trim().length < 8) {
                  return 'Please explain the issue clearly (min 8 characters)';
                }
                return null;
              },
              decoration: InputDecoration(
                labelText: 'Detailed Description of Incident',
                hintText: 'e.g. Broken packaging, missing item, or overcharging...',
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
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 14.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
              onPressed: _isSubmitting ? null : _submitDispute,
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
                      'Submit Dispute for Arbitration',
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
