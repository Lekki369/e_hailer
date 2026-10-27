import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../core/presentation/styles/app_colors.dart';
import '../../../../core/presentation/widgets/app_snackbar.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../auth/domain/user_entity.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/delivery_order.dart';
import '../../domain/entities/location_point.dart';
import '../../domain/entities/parcel_details.dart';
import '../../domain/services/pricing_calculator.dart';
import '../../domain/value_objects/delivery_status.dart';
import '../../domain/value_objects/delivery_type.dart';
import '../providers/delivery_providers.dart';

class ConsignmentCreationScreen extends HookConsumerWidget {
  const ConsignmentCreationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProfileProvider).value;

    // Sender Form State
    final senderNameController =
        useTextEditingController(text: user?.fullName ?? '');
    final senderPhoneController =
        useTextEditingController(text: user?.phone ?? '');
    final senderAddressController =
        useTextEditingController(text: 'Hub Dispatch Center, Ikeja');

    // Recipient Form State
    final recipientNameController = useTextEditingController();
    final recipientPhoneController = useTextEditingController();
    final recipientAddressController = useTextEditingController();

    // Package Specification State (from courierManagementSystem)
    final selectedCategory = useState<PackageCategory>(PackageCategory.parcel);
    final quantity = useState<int>(1);
    final weightController = useTextEditingController(text: '2.0');
    final lengthController = useTextEditingController(text: '30');
    final widthController = useTextEditingController(text: '20');
    final heightController = useTextEditingController(text: '15');
    final isFragile = useState<bool>(false);
    final descriptionController = useTextEditingController();

    final isSubmitting = useState<bool>(false);

    // Rebuild calculations whenever weight or dimensions change
    useListenable(weightController);
    useListenable(lengthController);
    useListenable(widthController);
    useListenable(heightController);

    // Parse numeric inputs
    final physicalWeight = double.tryParse(weightController.text) ?? 1.0;
    final length = double.tryParse(lengthController.text) ?? 10.0;
    final width = double.tryParse(widthController.text) ?? 10.0;
    final height = double.tryParse(heightController.text) ?? 10.0;

    // Volumetric calculation: (L * W * H) / 5000 (IATA standard from CMS)
    final volumetricWeight = (length * width * height) / 5000.0;
    final billableWeight =
        physicalWeight > volumetricWeight ? physicalWeight : volumetricWeight;

    // Calculate dynamic consignment fare
    final parcel = ParcelDetails(
      category: selectedCategory.value,
      weightKg: physicalWeight,
      quantity: quantity.value,
      lengthCm: length,
      widthCm: width,
      heightCm: height,
      description: descriptionController.text.trim(),
      isFragile: isFragile.value,
    );

    // Standard consignment distance estimate (e.g. 15 km hub-to-hub default)
    final pricing = PricingCalculator.calculate(
      distanceKm: 15.0,
      parcel: parcel,
      vehicleType: VehicleType.van,
    );

    // Generate random 4-digit security PIN for delivery verification without cloud storage
    final securityOtp = useMemoized(() {
      final rand = Random();
      return (1000 + rand.nextInt(9000)).toString();
    });

    Future<void> handleCreateConsignment() async {
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (user == null && firebaseUser == null) {
        AppSnackBar.showError(
          context,
          'You must be signed in to book a consignment. Please log in.',
          title: 'Sign In Required',
        );
        return;
      }

      final activeUser = user ??
          UserEntity(
            uid: firebaseUser!.uid,
            fullName: senderNameController.text.trim().isNotEmpty
                ? senderNameController.text.trim()
                : (firebaseUser.displayName ?? 'Sender'),
            email: firebaseUser.email ?? '',
            phone: senderPhoneController.text.trim(),
            role: UserRole.customer,
            createdAt: DateTime.now(),
          );

      if (senderNameController.text.trim().isEmpty) {
        AppSnackBar.showWarning(
          context,
          'Please enter the sender full name.',
          title: 'Sender Name Required',
        );
        return;
      }

      if (senderPhoneController.text.trim().isEmpty) {
        AppSnackBar.showWarning(
          context,
          'Please enter the sender contact phone number.',
          title: 'Sender Phone Required',
        );
        return;
      }

      if (senderAddressController.text.trim().isEmpty) {
        AppSnackBar.showWarning(
          context,
          'Please enter the sender origin pickup address.',
          title: 'Pickup Address Required',
        );
        return;
      }

      if (recipientNameController.text.trim().isEmpty) {
        AppSnackBar.showWarning(
          context,
          'Please enter the recipient full name.',
          title: 'Recipient Name Required',
        );
        return;
      }

      if (recipientPhoneController.text.trim().isEmpty) {
        AppSnackBar.showWarning(
          context,
          'Please enter the recipient contact phone number.',
          title: 'Recipient Phone Required',
        );
        return;
      }

      if (recipientAddressController.text.trim().isEmpty) {
        AppSnackBar.showWarning(
          context,
          'Please enter the recipient delivery address.',
          title: 'Delivery Address Required',
        );
        return;
      }

      if (parcel.weightKg <= 0) {
        AppSnackBar.showWarning(
          context,
          'Parcel weight must be greater than 0 kg.',
          title: 'Invalid Weight',
        );
        return;
      }

      isSubmitting.value = true;
      final trackingNumber =
          'WAYBILL-${DateTime.now().millisecondsSinceEpoch.toString().substring(4)}';

      final order = DeliveryOrder(
        id: '',
        trackingNumber: trackingNumber,
        type: DeliveryType.consignment,
        vehicleType: VehicleType.van,
        status: DeliveryStatus.created,
        customerId: activeUser.uid,
        customerName: senderNameController.text.trim(),
        customerPhone: senderPhoneController.text.trim(),
        pickupLocation: LocationPoint(
          latitude: 6.6018,
          longitude: 3.3515,
          address: senderAddressController.text.trim(),
          contactName: senderNameController.text.trim(),
          contactPhone: senderPhoneController.text.trim(),
        ),
        dropoffLocation: LocationPoint(
          latitude: 6.4531,
          longitude: 3.3958,
          address: recipientAddressController.text.trim(),
          contactName: recipientNameController.text.trim(),
          contactPhone: recipientPhoneController.text.trim(),
        ),
        parcel: parcel,
        pricing: pricing,
        distanceKm: 15.0,
        estimatedDurationMinutes: 60,
        createdAt: DateTime.now(),
        recipientSecurityOtp: securityOtp,
      );

      final result =
          await ref.read(deliveryRemoteServiceProvider).createOrder(order);
      isSubmitting.value = false;

      result.fold(
        (failure) {
          AppSnackBar.showError(context, failure.message);
        },
        (created) {
          context.pushReplacement(OrderTrackingRoute.pathWithId(created.id));
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Consignment Shipment'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Section 1: Sender Information
            _buildSectionHeader('1. Sender Information', Icons.person_outline),
            const SizedBox(height: 12),
            TextField(
              controller: senderNameController,
              decoration: const InputDecoration(labelText: 'Sender Full Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: senderPhoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Sender Phone Number'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: senderAddressController,
              decoration: const InputDecoration(labelText: 'Origin / Dispatch Hub Address'),
            ),
            const SizedBox(height: 24),

            // Section 2: Recipient Information
            _buildSectionHeader(
                '2. Recipient Information', Icons.local_shipping_outlined),
            const SizedBox(height: 12),
            TextField(
              controller: recipientNameController,
              decoration:
                  const InputDecoration(labelText: 'Recipient Full Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: recipientPhoneController,
              keyboardType: TextInputType.phone,
              decoration:
                  const InputDecoration(labelText: 'Recipient Phone Number'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: recipientAddressController,
              decoration: const InputDecoration(
                labelText: 'Destination Street Address',
                hintText: 'e.g. 14 Marina Road, Lagos Island',
              ),
            ),
            const SizedBox(height: 24),

            // Section 3: Package & Volumetric Dimensions (from CMS)
            _buildSectionHeader(
                '3. Package & Volumetric Dimensions', Icons.inventory_2_outlined),
            const SizedBox(height: 12),

            // Category Selector
            DropdownButtonFormField<PackageCategory>(
              initialValue: selectedCategory.value,
              decoration: const InputDecoration(labelText: 'Package Category'),
              items: PackageCategory.values.map((cat) {
                return DropdownMenuItem(
                  value: cat,
                  child: Text(cat.label),
                );
              }).toList(),
              onChanged: (cat) {
                if (cat != null) selectedCategory.value = cat;
              },
            ),
            const SizedBox(height: 12),

            // Weight & Quantity
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: weightController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Actual Weight',
                      suffixText: 'kg',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Qty', style: TextStyle(fontSize: 14)),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove, size: 18),
                              onPressed: quantity.value > 1
                                  ? () => quantity.value--
                                  : null,
                            ),
                            Text(
                              '${quantity.value}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add, size: 18),
                              onPressed: () => quantity.value++,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Dimension Inputs (Length x Width x Height)
            const Text(
              'Package Dimensions (L × W × H)',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: lengthController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Length',
                      suffixText: 'cm',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: widthController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Width',
                      suffixText: 'cm',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: heightController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Height',
                      suffixText: 'cm',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Live Volumetric Calculation Box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: volumetricWeight > physicalWeight
                    ? Colors.amber.shade50
                    : AppColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: volumetricWeight > physicalWeight
                      ? Colors.amber.shade300
                      : AppColors.divider,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Volumetric Weight:',
                        style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                      Text(
                        '${volumetricWeight.toStringAsFixed(2)} kg',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Billable Weight (Max):',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                      Text(
                        '${billableWeight.toStringAsFixed(2)} kg',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.secondary,
                        ),
                      ),
                    ],
                  ),
                  if (volumetricWeight > physicalWeight) ...[
                    const SizedBox(height: 6),
                    Text(
                      '⚡ Volumetric weight applies because the package is bulky relative to its weight.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.amber.shade900,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Fragile Checkbox
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Fragile Package / Handle with Care'),
              subtitle: const Text('+₦300 protective handling surcharge'),
              value: isFragile.value,
              activeColor: AppColors.secondary,
              onChanged: (val) => isFragile.value = val ?? false,
            ),
            const SizedBox(height: 8),

            TextField(
              controller: descriptionController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Package Description / Notes',
                hintText: 'e.g. Spare auto parts, fragile glass interior',
              ),
            ),
            const SizedBox(height: 24),

            // Section 4: Security PIN (Eliminating Cloud Storage for Signatures)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.shield_outlined, color: AppColors.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Delivery Verification PIN',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Recipient provides this OTP ($securityOtp) to driver on arrival.',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      securityOtp,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Cost Summary Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Base Consignment Fee:'),
                      Text('₦${pricing.baseFare.toStringAsFixed(0)}'),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Distance Fare (15 km):'),
                      Text('₦${pricing.distanceFare.toStringAsFixed(0)}'),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Weight Surcharge:'),
                      Text('₦${pricing.weightSurcharge.toStringAsFixed(0)}'),
                    ],
                  ),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Consignment Fare:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        '₦${pricing.totalFare.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.secondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Submit Button
            ElevatedButton(
              onPressed: isSubmitting.value ? null : handleCreateConsignment,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              child: isSubmitting.value
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Generate Waybill & Place Shipment'),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }
}
