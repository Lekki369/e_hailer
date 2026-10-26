import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../core/presentation/styles/app_colors.dart';
import '../../../auth/domain/user_entity.dart';
import '../providers/wallet_providers.dart';

/// Modal bottom sheet for drivers to request a bank withdrawal from their digital wallet.
class PayoutRequestModal extends StatefulHookConsumerWidget {
  final UserEntity user;

  const PayoutRequestModal({
    super.key,
    required this.user,
  });

  static Future<void> show(BuildContext context, UserEntity user) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PayoutRequestModal(user: user),
    );
  }

  @override
  ConsumerState<PayoutRequestModal> createState() => _PayoutRequestModalState();
}

class _PayoutRequestModalState extends ConsumerState<PayoutRequestModal> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _accountNameController = TextEditingController();

  String _selectedBank = 'Access Bank';
  bool _isSubmitting = false;

  final List<String> _nigerianBanks = [
    'Access Bank',
    'Guaranty Trust Bank (GTBank)',
    'Zenith Bank',
    'First Bank of Nigeria',
    'United Bank for Africa (UBA)',
    'Kuda Microfinance Bank',
    'Opay',
    'Palmpay',
    'Stanbic IBTC Bank',
    'Fidelity Bank',
  ];

  @override
  void initState() {
    super.initState();
    _accountNameController.text = widget.user.fullName;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _accountNumberController.dispose();
    _accountNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final balance = widget.user.walletBalance;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 24.h + MediaQuery.of(context).viewInsets.bottom),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Request Bank Payout',
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

              // Available Balance Card
              Container(
                padding: EdgeInsets.all(14.w),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(14.r),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.15),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Available Withdrawable Balance',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          '₦${balance.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 20.sp,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    Icon(
                      Icons.account_balance_wallet,
                      color: AppColors.primary,
                      size: 28.w,
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16.h),

              // Amount Field
              TextFormField(
                controller: _amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
                decoration: InputDecoration(
                  labelText: 'Withdrawal Amount (₦)',
                  hintText: 'e.g. 5000',
                  prefixText: '₦ ',
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter a withdrawal amount';
                  }
                  final amount = double.tryParse(val.trim());
                  if (amount == null || amount <= 0) {
                    return 'Enter a valid amount';
                  }
                  if (amount > balance) {
                    return 'Amount exceeds your available balance (₦${balance.toStringAsFixed(0)})';
                  }
                  return null;
                },
              ),
              SizedBox(height: 10.h),

              // Quick preset buttons
              Row(
                children: [
                  _buildPresetChip('₦2,000', 2000, balance),
                  SizedBox(width: 8.w),
                  _buildPresetChip('₦5,000', 5000, balance),
                  SizedBox(width: 8.w),
                  _buildPresetChip('₦10,000', 10000, balance),
                  SizedBox(width: 8.w),
                  _buildPresetChip('All', balance, balance),
                ],
              ),
              SizedBox(height: 16.h),

              // Bank selector
              DropdownButtonFormField<String>(
                initialValue: _selectedBank,
                decoration: InputDecoration(
                  labelText: 'Destination Bank',
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide: BorderSide.none,
                  ),
                ),
                items: _nigerianBanks.map((bank) {
                  return DropdownMenuItem(
                    value: bank,
                    child: Text(bank, style: TextStyle(fontSize: 13.sp)),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedBank = val);
                  }
                },
              ),
              SizedBox(height: 12.h),

              // Account Number
              TextFormField(
                controller: _accountNumberController,
                keyboardType: TextInputType.number,
                maxLength: 10,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: '10-Digit NUBAN Account Number',
                  counterText: '',
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().length != 10) {
                    return 'Please enter a valid 10-digit account number';
                  }
                  return null;
                },
              ),
              SizedBox(height: 12.h),

              // Account Name
              TextFormField(
                controller: _accountNameController,
                decoration: InputDecoration(
                  labelText: 'Account Holder Name',
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter the registered account name';
                  }
                  return null;
                },
              ),
              SizedBox(height: 20.h),

              // Submit Button
              ElevatedButton(
                onPressed: _isSubmitting || balance <= 0
                    ? null
                    : () async {
                        if (!_formKey.currentState!.validate()) return;

                        setState(() => _isSubmitting = true);
                        final amount =
                            double.parse(_amountController.text.trim());

                        final service = ref.read(walletRemoteServiceProvider);
                        final result = await service.submitPayoutRequest(
                          driverId: widget.user.uid,
                          driverName: widget.user.fullName,
                          driverPhone: widget.user.phone,
                          currentBalance: balance,
                          amount: amount,
                          bankName: _selectedBank,
                          accountNumber:
                              _accountNumberController.text.trim(),
                          accountName: _accountNameController.text.trim(),
                        );

                        if (mounted) {
                          setState(() => _isSubmitting = false);
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
                                    'Payout request of ₦${amount.toStringAsFixed(0)} submitted successfully! Funds will be settled to your bank account.',
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
                        'Submit Withdrawal Request',
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPresetChip(String label, double val, double balance) {
    final isEnabled = val > 0 && val <= balance;
    return Expanded(
      child: OutlinedButton(
        onPressed: isEnabled
            ? () {
                _amountController.text = val.toStringAsFixed(0);
              }
            : null,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.symmetric(vertical: 8.h),
          side: BorderSide(
            color: isEnabled ? AppColors.primary : Colors.grey.shade300,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.r),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.sp,
            fontWeight: FontWeight.w600,
            color: isEnabled ? AppColors.primary : Colors.grey.shade400,
          ),
        ),
      ),
    );
  }
}
