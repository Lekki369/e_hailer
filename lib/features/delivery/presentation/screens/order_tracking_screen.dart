import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/presentation/styles/app_colors.dart';
import '../../../../core/presentation/widgets/app_snackbar.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../map/presentation/widgets/osm_map_widget.dart';
import '../../../wallet/presentation/widgets/fare_breakdown_bottom_sheet.dart';
import '../../domain/entities/delivery_order.dart';
import '../../domain/value_objects/delivery_status.dart';
import '../providers/delivery_providers.dart';
import '../widgets/file_dispute_modal.dart';

class OrderTrackingScreen extends HookConsumerWidget {
  final String orderId;

  const OrderTrackingScreen({
    super.key,
    required this.orderId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderStream = ref.watch(activeOrderStreamProvider(orderId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Delivery Tracking'),
      ),
      body: orderStream.when(
        data: (result) => result.fold(
          (failure) => Center(
            child: Text(
              failure.message,
              style: const TextStyle(color: AppColors.error),
            ),
          ),
          (order) {
            final isDelivered = order.status == DeliveryStatus.delivered;
            final isCancelled = order.status == DeliveryStatus.cancelled;
            final canCancel = order.status == DeliveryStatus.searchingDriver ||
                order.status == DeliveryStatus.assigned ||
                order.status == DeliveryStatus.arrivedPickup;

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Live Interactive OSM Map
                  SizedBox(
                    height: 280,
                    child: OsmMapWidget(
                      pickupLocation: LatLng(
                        order.pickupLocation.latitude,
                        order.pickupLocation.longitude,
                      ),
                      dropoffLocation: LatLng(
                        order.dropoffLocation.latitude,
                        order.dropoffLocation.longitude,
                      ),
                      driverLocation: order.driverLatitude != null &&
                              order.driverLongitude != null
                          ? LatLng(order.driverLatitude!, order.driverLongitude!)
                          : null,
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 2. Cancellation Banner (If Cancelled)
                        if (isCancelled) ...[
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.error),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.cancel_rounded,
                                        color: AppColors.error),
                                    SizedBox(width: 8),
                                    Text(
                                      'Order Cancelled',
                                      style: TextStyle(
                                        color: AppColors.error,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Reason: ${order.cancellationReason ?? 'No reason provided.'}',
                                  style: const TextStyle(fontSize: 13),
                                ),
                                if (order.cancelledByRole != null)
                                  Text(
                                    'Cancelled by: ${order.cancelledByRole!.toUpperCase()}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // 3. Post-Delivery Rating & Review Section (If Delivered)
                        if (isDelivered) ...[
                          _RatingSection(order: order),
                          const SizedBox(height: 16),
                        ],

                        // 4. Consignment Waybill & QR Code Header
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.divider),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              QrImageView(
                                data: order.trackingNumber,
                                version: QrVersions.auto,
                                size: 72,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Consignment Waybill',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      order.trackingNumber,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isCancelled
                                            ? AppColors.error
                                                .withValues(alpha: 0.12)
                                            : AppColors.secondary
                                                .withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        order.status.label,
                                        style: TextStyle(
                                          color: isCancelled
                                              ? AppColors.error
                                              : AppColors.secondary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Share Public Tracking Link Card
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.divider),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.link_rounded,
                                      color: AppColors.secondary, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Public Tracking Link',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              TextButton.icon(
                                icon: const Icon(Icons.copy_rounded, size: 15),
                                label: const Text('Copy Link'),
                                onPressed: () {
                                  final link =
                                      'https://ehailer.app/track/${order.trackingNumber}';
                                  Clipboard.setData(ClipboardData(text: link));
                                  AppSnackBar.showSuccess(
                                    context,
                                    'Shareable link copied: $link',
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Financial Fare Breakdown summary
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.divider),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Delivery Fare',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  Text(
                                    '₦${order.pricing.totalFare.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                              TextButton.icon(
                                icon: const Icon(Icons.receipt_long, size: 16),
                                label: const Text('View Breakdown'),
                                onPressed: () {
                                  FareBreakdownBottomSheet.show(context, order);
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Report Problem / File Dispute Button
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textSecondary,
                            side: const BorderSide(color: AppColors.divider),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.support_agent_rounded, size: 18),
                          label: const Text('Report an Issue or File Claim'),
                          onPressed: () {
                            final user =
                                ref.read(currentUserProfileProvider).value;
                            FileDisputeModal.show(context, order,
                                currentUser: user);
                          },
                        ),
                        const SizedBox(height: 18),

                        // Delivery Milestone Progress Timeline
                        _buildProgressTimeline(order),
                        const SizedBox(height: 18),

                        // 5. Assigned Driver Card (from MyOGA)
                        if (order.driverId != null) ...[
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.divider),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor:
                                      AppColors.primary.withValues(alpha: 0.1),
                                  child: const Icon(
                                    Icons.person,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        order.driverName ?? 'Assigned Rider',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        order.vehicleType.label,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.phone_rounded,
                                  color: AppColors.success,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],

                        // 6. Route & Address Details
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.divider),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Route Information',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.trip_origin_rounded,
                                    size: 18,
                                    color: AppColors.success,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Pickup Address',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          order.pickupLocation.address,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const Padding(
                                padding: EdgeInsets.only(
                                    left: 8.0, top: 4, bottom: 4),
                                child: SizedBox(
                                  height: 20,
                                  child: VerticalDivider(
                                    color: AppColors.divider,
                                    thickness: 2,
                                  ),
                                ),
                              ),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.location_on_rounded,
                                    size: 18,
                                    color: AppColors.error,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Delivery Destination',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          order.dropoffLocation.address,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // 7. Consignment Specifications & PIN Verification
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.divider),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Consignment Details',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Category:',
                                      style: TextStyle(
                                          color: AppColors.textSecondary)),
                                  Text(order.parcel.category.label,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600)),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Actual Weight:',
                                      style: TextStyle(
                                          color: AppColors.textSecondary)),
                                  Text('${order.parcel.weightKg} kg',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600)),
                                ],
                              ),
                              if (order.parcel.lengthCm != null) ...[
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Dimensions (L×W×H):',
                                        style: TextStyle(
                                            color: AppColors.textSecondary)),
                                    Text(
                                        '${order.parcel.lengthCm} × ${order.parcel.widthCm} × ${order.parcel.heightCm} cm',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600)),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Billable Weight:',
                                        style: TextStyle(
                                            color: AppColors.textSecondary)),
                                    Text(
                                      '${order.parcel.billableWeightKg.toStringAsFixed(2)} kg',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.secondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              if (order.recipientSecurityOtp != null) ...[
                                const Divider(height: 24),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Delivery Handover PIN',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                          ),
                                          Text(
                                            'Recipient shows this code to rider',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        order.recipientSecurityOtp!,
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primary,
                                          letterSpacing: 2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // 8. Order Cancellation Button (If eligible)
                        if (canCancel)
                          OutlinedButton.icon(
                            icon: const Icon(Icons.cancel_outlined,
                                color: AppColors.error),
                            label: const Text(
                              'Cancel Delivery Request',
                              style: TextStyle(color: AppColors.error),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.error),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () {
                              _showCancellationDialog(context, ref, order);
                            },
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading order: $e')),
      ),
    );
  }

  void _showCancellationDialog(
      BuildContext context, WidgetRef ref, DeliveryOrder order) {
    final reasons = [
      'Found alternative courier or ride',
      'Driver taking too long to arrive',
      'Incorrect pickup or dropoff address',
      'Changed mind / no longer needed',
      'Other reason',
    ];

    final selectedReason = ValueNotifier<String>(reasons.first);
    final isSubmitting = ValueNotifier<bool>(false);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalContext) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Cancel Delivery Order',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Please select the reason why you are cancelling this request:',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),

              ValueListenableBuilder<String>(
                valueListenable: selectedReason,
                builder: (context, current, _) {
                  return Column(
                    children: reasons.map((reason) {
                      final isSelected = current == reason;
                      return InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => selectedReason.value = reason,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.error.withValues(alpha: 0.08)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.error
                                  : AppColors.divider,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isSelected
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_unchecked,
                                size: 18,
                                color: isSelected
                                    ? AppColors.error
                                    : AppColors.textMuted,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  reason,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                    color: isSelected
                                        ? AppColors.error
                                        : AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: 16),

              ValueListenableBuilder<bool>(
                valueListenable: isSubmitting,
                builder: (context, loading, _) {
                  return ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: loading
                        ? null
                        : () async {
                            isSubmitting.value = true;
                            final res = await ref
                                .read(deliveryRemoteServiceProvider)
                                .cancelOrder(
                                  orderId: order.id,
                                  reason: selectedReason.value,
                                  cancelledByRole: 'customer',
                                );
                            isSubmitting.value = false;

                            res.fold(
                              (f) => AppSnackBar.showError(context, f.message),
                              (_) {
                                Navigator.of(modalContext).pop();
                                AppSnackBar.showError(
                                  context,
                                  'Order has been cancelled.',
                                );
                              },
                            );
                          },
                    child: loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Confirm Cancellation'),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProgressTimeline(DeliveryOrder order) {
    final status = order.status;
    final isCancelled = status == DeliveryStatus.cancelled;

    final steps = [
      (
        title: 'Shipment Created',
        subtitle: DateFormat('MMM d, h:mm a').format(order.createdAt),
        isCompleted: true,
        isActive: status == DeliveryStatus.searchingDriver,
      ),
      (
        title: 'Courier Assigned',
        subtitle: order.assignedAt != null
            ? 'Dispatched ${DateFormat('MMM d, h:mm a').format(order.assignedAt!)}'
            : (order.driverName != null
                ? '${order.driverName} dispatched'
                : 'Matching nearby fleet rider'),
        isCompleted: status != DeliveryStatus.searchingDriver && !isCancelled,
        isActive: status == DeliveryStatus.assigned,
      ),
      (
        title: 'Package Picked Up',
        subtitle: order.pickedUpAt != null
            ? 'Picked up ${DateFormat('MMM d, h:mm a').format(order.pickedUpAt!)}'
            : 'Courier received consignment from sender',
        isCompleted: status == DeliveryStatus.pickedUp ||
            status == DeliveryStatus.inTransit ||
            status == DeliveryStatus.arrivedDropoff ||
            status == DeliveryStatus.delivered,
        isActive: status == DeliveryStatus.arrivedPickup,
      ),
      (
        title: 'In Transit',
        subtitle: order.inTransitAt != null
            ? 'En route since ${DateFormat('MMM d, h:mm a').format(order.inTransitAt!)}'
            : 'En route to recipient destination',
        isCompleted: status == DeliveryStatus.arrivedDropoff ||
            status == DeliveryStatus.delivered,
        isActive: status == DeliveryStatus.inTransit,
      ),
      (
        title: 'Delivered & Handover Confirmed',
        subtitle: order.deliveredAt != null
            ? 'Delivered ${DateFormat('MMM d, h:mm a').format(order.deliveredAt!)} (PIN verified)'
            : 'Security OTP verified at drop-off',
        isCompleted: status == DeliveryStatus.delivered,
        isActive: status == DeliveryStatus.arrivedDropoff,
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Delivery Milestone Timeline',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: steps.length,
            itemBuilder: (context, index) {
              final step = steps[index];
              final isLast = index == steps.length - 1;

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: step.isCompleted
                              ? AppColors.success
                              : step.isActive
                                  ? AppColors.secondary
                                  : AppColors.divider,
                        ),
                        child: Icon(
                          step.isCompleted
                              ? Icons.check
                              : step.isActive
                                  ? Icons.radio_button_checked
                                  : Icons.circle,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                      if (!isLast)
                        Container(
                          width: 2,
                          height: 28,
                          color: step.isCompleted
                              ? AppColors.success
                              : AppColors.divider,
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            step.title,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: step.isCompleted || step.isActive
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            step.subtitle,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _RatingSection extends HookConsumerWidget {
  final DeliveryOrder order;

  const _RatingSection({required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rating = useState<int>(order.customerRating?.toInt() ?? 5);
    final reviewController =
        useTextEditingController(text: order.customerReview ?? '');
    final isSubmitting = useState<bool>(false);
    final isSubmitted = useState<bool>(order.customerRating != null);

    if (isSubmitted.value) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.success),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.star_rounded, color: Colors.amber, size: 24),
                const SizedBox(width: 6),
                Text(
                  'You rated this delivery ${order.customerRating?.toStringAsFixed(1) ?? '5.0'} / 5.0',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            if ((order.customerReview ?? '').isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                '"${order.customerReview}"',
                style: const TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Rate Your Delivery Experience',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'How was your service with ${order.driverName ?? 'the rider'}?',
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),

          // 5-Star Row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final starValue = index + 1;
              return IconButton(
                icon: Icon(
                  starValue <= rating.value
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  color: Colors.amber.shade700,
                  size: 32,
                ),
                onPressed: () => rating.value = starValue,
              );
            }),
          ),
          const SizedBox(height: 10),

          TextField(
            controller: reviewController,
            maxLines: 2,
            decoration: const InputDecoration(
              hintText: 'Add an optional note or review for the driver...',
              hintStyle: TextStyle(fontSize: 12, color: AppColors.textMuted),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),

          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onPressed: isSubmitting.value
                ? null
                : () async {
                    isSubmitting.value = true;
                    final res = await ref
                        .read(deliveryRemoteServiceProvider)
                        .rateDeliveryOrder(
                          orderId: order.id,
                          driverId: order.driverId ?? '',
                          rating: rating.value.toDouble(),
                          review: reviewController.text.trim(),
                        );
                    isSubmitting.value = false;

                    res.fold(
                      (f) => AppSnackBar.showError(context, f.message),
                      (_) {
                        isSubmitted.value = true;
                        AppSnackBar.showSuccess(
                          context,
                          'Thank you! Your rating has been recorded.',
                        );
                      },
                    );
                  },
            child: isSubmitting.value
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Submit Rating & Review'),
          ),
        ],
      ),
    );
  }
}
