import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:pinput/pinput.dart';

import '../../../../core/presentation/styles/app_colors.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../map/domain/route_result.dart';
import '../../../map/infrastructure/osm_routing_service.dart';
import '../../../map/presentation/providers/map_providers.dart';
import '../../../map/presentation/widgets/osm_map_widget.dart';
import '../../domain/entities/delivery_order.dart';
import '../../domain/value_objects/delivery_status.dart';
import '../providers/delivery_providers.dart';

class ActiveDeliveryScreen extends HookConsumerWidget {
  final String orderId;

  const ActiveDeliveryScreen({
    super.key,
    required this.orderId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(activeOrderStreamProvider(orderId));
    final driver = ref.watch(currentUserProfileProvider).value;
    final isUpdatingStatus = useState(false);
    final routingService = useMemoized(() => OsmRoutingService());
    final routeResult = useState<RouteResult?>(null);
    final broadcastService = ref.watch(driverLocationBroadcastServiceProvider);
    final isLiveBroadcasting = useState(false);
    final isSyncingGps = useState(false);

    useEffect(() {
      return () {
        broadcastService.stopLiveBroadcast();
      };
    }, const []);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Active Delivery Dispatch'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: orderAsync.when(
        data: (orderResult) {
          return orderResult.fold(
            (failure) => Center(child: Text(failure.message)),
            (order) {
              final isDelivered = order.status == DeliveryStatus.delivered;
              final driverEarnings = order.pricing.driverEarnings ??
                  (order.pricing.totalFare * 0.8);

              // Calculate road routing once order is loaded
              useEffect(() {
                routingService
                    .getDrivingRoute(
                  origin: LatLng(order.pickupLocation.latitude,
                      order.pickupLocation.longitude),
                  destination: LatLng(order.dropoffLocation.latitude,
                      order.dropoffLocation.longitude),
                )
                    .then((result) {
                  result.fold((_) => null, (res) => routeResult.value = res);
                });
                return null;
              }, [order.id]);

              return Column(
                children: [
                  // 1. Interactive Road Map Preview
                  SizedBox(
                    height: 260,
                    child: OsmMapWidget(
                      pickupLocation: LatLng(
                        order.pickupLocation.latitude,
                        order.pickupLocation.longitude,
                      ),
                      dropoffLocation: LatLng(
                        order.dropoffLocation.latitude,
                        order.dropoffLocation.longitude,
                      ),
                      driverLocation: LatLng(
                        order.driverLatitude ?? order.pickupLocation.latitude,
                        order.driverLongitude ?? order.pickupLocation.longitude,
                      ),
                      routePoints: routeResult.value?.points ?? [],
                    ),
                  ),

                  // 2. Live GPS Broadcast Toolbar
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        bottom: BorderSide(color: AppColors.divider),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: isLiveBroadcasting.value
                                    ? AppColors.success
                                    : AppColors.textMuted,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isLiveBroadcasting.value
                                  ? 'GPS Stream: ACTIVE'
                                  : 'GPS Broadcast: OFF',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isLiveBroadcasting.value
                                    ? AppColors.success
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            TextButton.icon(
                              icon: isSyncingGps.value
                                  ? const SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : const Icon(Icons.my_location_rounded,
                                      size: 15),
                              label: const Text('Broadcast GPS',
                                  style: TextStyle(fontSize: 11)),
                              onPressed: isSyncingGps.value || isDelivered
                                  ? null
                                  : () async {
                                      isSyncingGps.value = true;
                                      final res = await broadcastService
                                          .broadcastCurrentLocation(order.id);
                                      isSyncingGps.value = false;
                                      res.fold(
                                        (f) => ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                              content: Text(f.message)),
                                        ),
                                        (pos) => ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            backgroundColor:
                                                AppColors.success,
                                            content: Text(
                                                'GPS broadcasted (${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)})'),
                                          ),
                                        ),
                                      );
                                    },
                            ),
                            Switch(
                              value: isLiveBroadcasting.value,
                              activeThumbColor: AppColors.success,
                              onChanged: isDelivered
                                  ? null
                                  : (val) async {
                                      if (val) {
                                        final res = await broadcastService
                                            .startLiveBroadcast(order.id);
                                        res.fold(
                                          (f) => ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                                content: Text(f.message)),
                                          ),
                                          (_) {
                                            isLiveBroadcasting.value = true;
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                backgroundColor:
                                                    AppColors.success,
                                                content: Text(
                                                    'Live GPS stream started! Position updates sync live.'),
                                              ),
                                            );
                                          },
                                        );
                                      } else {
                                        await broadcastService
                                            .stopLiveBroadcast();
                                        isLiveBroadcasting.value = false;
                                      }
                                    },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // 3. Order Header & Trip Stage
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Waybill & Status Row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    order.trackingNumber,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${order.type.name.toUpperCase()} • ${order.vehicleType.name.toUpperCase()}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryLight,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  order.status.label.toUpperCase(),
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Driver Earnings Card (80% Net Payout)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.divider),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Your Trip Payout (80%)',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Direct to Digital Wallet',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.success,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  '₦${driverEarnings.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.secondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Location Points & Contacts
                          _LocationCard(
                            title: '1. Pickup Location',
                            address: order.pickupLocation.address,
                            contactName: order.pickupLocation.contactName.isNotEmpty
                                ? order.pickupLocation.contactName
                                : order.customerName,
                            contactPhone: order.pickupLocation.contactPhone.isNotEmpty
                                ? order.pickupLocation.contactPhone
                                : order.customerPhone,
                            isDone: order.status != DeliveryStatus.assigned &&
                                order.status != DeliveryStatus.arrivedPickup,
                          ),
                          const SizedBox(height: 12),
                          _LocationCard(
                            title: '2. Dropoff Destination',
                            address: order.dropoffLocation.address,
                            contactName: order.dropoffLocation.contactName.isNotEmpty
                                ? order.dropoffLocation.contactName
                                : order.customerName,
                            contactPhone:
                                order.dropoffLocation.contactPhone.isNotEmpty
                                    ? order.dropoffLocation.contactPhone
                                    : order.customerPhone,
                            isDone: isDelivered,
                          ),
                          const SizedBox(height: 24),

                          // 3. Status Action Workflow Button
                          if (!isDelivered)
                            _buildActionWorkflowButton(
                              context: context,
                              ref: ref,
                              order: order,
                              driverId: driver?.uid ?? '',
                              isUpdating: isUpdatingStatus,
                            )
                          else
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.success.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.success),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.check_circle_rounded,
                                      color: AppColors.success),
                                  SizedBox(width: 8),
                                  Text(
                                    'Delivery Completed & Verified',
                                    style: TextStyle(
                                      color: AppColors.success,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildActionWorkflowButton({
    required BuildContext context,
    required WidgetRef ref,
    required DeliveryOrder order,
    required String driverId,
    required ValueNotifier<bool> isUpdating,
  }) {
    final remoteService = ref.read(deliveryRemoteServiceProvider);

    if (order.status == DeliveryStatus.assigned) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton.icon(
            icon: const Icon(Icons.location_on_rounded),
            label: const Text('Arrived at Pickup Location'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            onPressed: isUpdating.value
                ? null
                : () async {
                    isUpdating.value = true;
                    await remoteService.updateStatus(
                      orderId: order.id,
                      status: DeliveryStatus.arrivedPickup,
                    );
                    isUpdating.value = false;
                  },
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            icon: const Icon(Icons.cancel_outlined,
                size: 16, color: AppColors.error),
            label: const Text(
              'Cancel Delivery Assignment',
              style: TextStyle(color: AppColors.error, fontSize: 13),
            ),
            onPressed: () {
              _showDriverCancellationDialog(context, ref, order);
            },
          ),
        ],
      );
    }

    if (order.status == DeliveryStatus.arrivedPickup) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton.icon(
            icon: const Icon(Icons.inventory_rounded),
            label: const Text('Package Collected / Start Trip'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            onPressed: isUpdating.value
                ? null
                : () async {
                    isUpdating.value = true;
                    await remoteService.updateStatus(
                      orderId: order.id,
                      status: DeliveryStatus.inTransit,
                    );
                    isUpdating.value = false;
                  },
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            icon: const Icon(Icons.cancel_outlined,
                size: 16, color: AppColors.error),
            label: const Text(
              'Cancel Delivery Assignment',
              style: TextStyle(color: AppColors.error, fontSize: 13),
            ),
            onPressed: () {
              _showDriverCancellationDialog(context, ref, order);
            },
          ),
        ],
      );
    }

    if (order.status == DeliveryStatus.inTransit ||
        order.status == DeliveryStatus.pickedUp) {
      return ElevatedButton.icon(
        icon: const Icon(Icons.where_to_vote_rounded),
        label: const Text('Arrived at Dropoff Destination'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        onPressed: isUpdating.value
            ? null
            : () async {
                isUpdating.value = true;
                await remoteService.updateStatus(
                  orderId: order.id,
                  status: DeliveryStatus.arrivedDropoff,
                );
                isUpdating.value = false;
              },
      );
    }

    // When at dropoff: Handover Verification PIN
    return ElevatedButton.icon(
      icon: const Icon(Icons.pin_rounded),
      label: const Text('Verify Handover PIN & Complete Delivery'),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.secondary,
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
      onPressed: isUpdating.value
          ? null
          : () {
              _showOtpVerificationDialog(
                context: context,
                ref: ref,
                order: order,
                driverId: driverId,
              );
            },
    );
  }

  void _showOtpVerificationDialog({
    required BuildContext context,
    required WidgetRef ref,
    required DeliveryOrder order,
    required String driverId,
  }) {
    final pinController = TextEditingController();
    final isVerifying = ValueNotifier<bool>(false);
    final errorMessage = ValueNotifier<String?>(null);
    final driverEarnings =
        order.pricing.driverEarnings ?? (order.pricing.totalFare * 0.8);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(modalContext).viewInsets.bottom + 24,
          ),
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
              const Row(
                children: [
                  Icon(Icons.shield_rounded, color: AppColors.secondary, size: 28),
                  SizedBox(width: 8),
                  Text(
                    'Handover Verification PIN',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Ask the recipient for the 4-digit security PIN displayed on their tracking screen.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),

              // Pinput 4-digit input widget
              Center(
                child: Pinput(
                  length: 4,
                  controller: pinController,
                  autofocus: true,
                  defaultPinTheme: PinTheme(
                    width: 56,
                    height: 56,
                    textStyle: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.divider),
                    ),
                  ),
                  focusedPinTheme: PinTheme(
                    width: 56,
                    height: 56,
                    textStyle: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.secondary,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: AppColors.secondary, width: 2),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              ValueListenableBuilder<String?>(
                valueListenable: errorMessage,
                builder: (context, error, _) {
                  if (error == null) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      error,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                },
              ),

              ValueListenableBuilder<bool>(
                valueListenable: isVerifying,
                builder: (context, verifying, _) {
                  return ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: verifying
                        ? null
                        : () async {
                            final input = pinController.text.trim();
                            if (input.length != 4) {
                              errorMessage.value =
                                  'Please enter the full 4-digit PIN.';
                              return;
                            }

                            isVerifying.value = true;
                            errorMessage.value = null;

                            final platformCommission =
                                order.pricing.platformCommission ??
                                    (order.pricing.totalFare * 0.2);
                            final isCod = order.pricing.paymentMethod.name ==
                                'cashOnDelivery';

                            final result = await ref
                                .read(deliveryRemoteServiceProvider)
                                .verifyAndCompleteDelivery(
                                  orderId: order.id,
                                  driverId: driverId,
                                  inputOtp: input,
                                  expectedOtp:
                                      order.recipientSecurityOtp ?? '',
                                  driverEarnings: driverEarnings,
                                  platformCommission: platformCommission,
                                  paymentMethod:
                                      order.pricing.paymentMethod.name,
                                  trackingNumber: order.trackingNumber,
                                );

                            isVerifying.value = false;

                            result.fold(
                              (failure) {
                                errorMessage.value = failure.message;
                              },
                              (_) {
                                Navigator.of(modalContext).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: AppColors.success,
                                    content: Text(
                                      isCod
                                          ? 'Handover verified! Cash collected. ₦${platformCommission.toStringAsFixed(0)} commission deducted from digital wallet.'
                                          : 'Handover verified! ₦${driverEarnings.toStringAsFixed(0)} credited to your digital wallet.',
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                    child: verifying
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Confirm Handover & Complete Delivery',
                            style: TextStyle(fontSize: 15),
                          ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDriverCancellationDialog(
      BuildContext context, WidgetRef ref, DeliveryOrder order) {
    final reasons = [
      'Customer unreachable / not at pickup address',
      'Package exceeds vehicle cargo limits',
      'Vehicle mechanical breakdown',
      'Severe weather or security risk',
      'Other emergency',
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
                'Cancel Delivery Assignment',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Please select why you cannot fulfill this delivery job:',
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
                                  cancelledByRole: 'driver',
                                );
                            isSubmitting.value = false;

                            res.fold(
                              (f) => ScaffoldMessenger.of(context)
                                  .showSnackBar(
                                SnackBar(content: Text(f.message)),
                              ),
                              (_) {
                                Navigator.of(modalContext).pop();
                                context.pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    backgroundColor: AppColors.error,
                                    content: Text('Job assignment cancelled.'),
                                  ),
                                );
                              },
                            );
                          },
                    child: loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
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
}

class _LocationCard extends StatelessWidget {
  final String title;
  final String address;
  final String contactName;
  final String contactPhone;
  final bool isDone;

  const _LocationCard({
    required this.title,
    required this.address,
    required this.contactName,
    required this.contactPhone,
    required this.isDone,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDone ? AppColors.success : AppColors.divider,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isDone ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 16,
                color: isDone ? AppColors.success : AppColors.textMuted,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: isDone ? AppColors.success : AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            address,
            style: const TextStyle(fontSize: 13),
          ),
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$contactName • $contactPhone',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const Icon(
                Icons.phone_rounded,
                size: 18,
                color: AppColors.primary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
