import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/presentation/styles/app_colors.dart';
import '../../../map/presentation/widgets/osm_map_widget.dart';
import '../../../wallet/presentation/widgets/fare_breakdown_bottom_sheet.dart';
import '../../domain/entities/delivery_order.dart';
import '../../domain/value_objects/delivery_status.dart';
import '../providers/delivery_providers.dart';
import '../widgets/file_dispute_modal.dart';

/// Public-facing unauthenticated tracking portal for Consignments & Waybills
class PublicTrackingScreen extends HookConsumerWidget {
  final String? initialTrackingNumber;

  const PublicTrackingScreen({
    super.key,
    this.initialTrackingNumber,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchController = useTextEditingController(
      text: initialTrackingNumber?.trim().toUpperCase() ?? '',
    );
    final activeTrackingCode = useState<String>(
      initialTrackingNumber?.trim().toUpperCase() ?? '',
    );

    final trackingQuery = activeTrackingCode.value.trim().toUpperCase();
    final trackingStreamAsync = trackingQuery.isNotEmpty
        ? ref.watch(publicOrderTrackingStreamProvider(trackingQuery))
        : null;

    void performSearch() {
      final code = searchController.text.trim().toUpperCase();
      if (code.isNotEmpty) {
        activeTrackingCode.value = code;
      }
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Track Shipment'),
        actions: [
          if (trackingQuery.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.share_outlined),
              tooltip: 'Share Tracking Link',
              onPressed: () {
                _copyTrackingLink(context, trackingQuery);
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Waybill / Tracking Search Bar
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(color: AppColors.divider),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 4.h),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded,
                      color: AppColors.textSecondary),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: TextField(
                      controller: searchController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        hintText: 'Enter Waybill # (e.g. WAYBILL-17...)',
                        border: InputBorder.none,
                      ),
                      onSubmitted: (_) => performSearch(),
                    ),
                  ),
                  if (searchController.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () {
                        searchController.clear();
                        activeTrackingCode.value = '';
                      },
                    ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      padding: EdgeInsets.symmetric(
                          horizontal: 14.w, vertical: 10.h),
                    ),
                    onPressed: performSearch,
                    child: Text('Track', style: TextStyle(fontSize: 13.sp)),
                  ),
                ],
              ),
            ),
            SizedBox(height: 18.h),

            // 2. Body State Routing: Idle vs Loading vs Data vs Error
            if (trackingQuery.isEmpty)
              _buildIdleState(context, searchController, activeTrackingCode)
            else if (trackingStreamAsync != null)
              trackingStreamAsync.when(
                loading: () => Container(
                  height: 350.h,
                  alignment: Alignment.center,
                  child: const CircularProgressIndicator(
                    color: AppColors.secondary,
                  ),
                ),
                error: (error, _) => _buildErrorCard(
                  'Failed to load tracking data: $error',
                ),
                data: (result) => result.fold(
                  (failure) => _buildNotFoundCard(context, trackingQuery),
                  (order) => _buildOrderTrackingContent(context, order),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Welcome state when no tracking code is submitted yet
  Widget _buildIdleState(
    BuildContext context,
    TextEditingController controller,
    ValueNotifier<String> activeCode,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 36.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 36.r,
            backgroundColor: AppColors.primary.withValues(alpha: 0.08),
            child: Icon(
              Icons.local_shipping_outlined,
              size: 38.r,
              color: AppColors.primary,
            ),
          ),
          SizedBox(height: 16.h),
          Text(
            'Instant Consignment & Parcel Tracking',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 17.sp,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Enter your unique consignment or express waybill number to view live GPS dispatch coordinates, delivery timeline, and courier contact.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.sp,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          SizedBox(height: 24.h),
          const Divider(),
          SizedBox(height: 16.h),
          Text(
            'FEATURED TRACKING CAPABILITIES',
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
              color: AppColors.textMuted,
            ),
          ),
          SizedBox(height: 14.h),
          _buildFeatureBullet(
            icon: Icons.map_outlined,
            title: 'Live OpenStreetMap Navigation',
            description: 'Free real-time driver coordinates and route path.',
          ),
          SizedBox(height: 10.h),
          _buildFeatureBullet(
            icon: Icons.verified_user_outlined,
            title: '4-Digit Recipient Handover PIN',
            description: 'Guaranteed fraud protection without paid cloud storage.',
          ),
          SizedBox(height: 10.h),
          _buildFeatureBullet(
            icon: Icons.qr_code_2_rounded,
            title: 'Digital Waybill Barcode',
            description: 'Instant on-screen QR verification at parcel drop-off.',
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureBullet({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20.r, color: AppColors.secondary),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12.sp,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Error state if tracking code does not exist in Firestore
  Widget _buildNotFoundCard(BuildContext context, String code) {
    return Container(
      padding: EdgeInsets.all(24.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(Icons.search_off_rounded,
              size: 52.r, color: AppColors.error),
          SizedBox(height: 12.h),
          Text(
            'Shipment Not Found',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            'We could not find any consignment matching "$code". Please double-check the tracking code and try again.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.sp,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(String message) {
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.error),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.error),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: AppColors.error, fontSize: 13.sp),
            ),
          ),
        ],
      ),
    );
  }

  /// Full tracking view when valid delivery order is found
  Widget _buildOrderTrackingContent(BuildContext context, DeliveryOrder order) {
    final isDelivered = order.status == DeliveryStatus.delivered;
    final isCancelled = order.status == DeliveryStatus.cancelled;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Live Interactive OSM Map
        Container(
          height: 250.h,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: AppColors.divider),
          ),
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
        SizedBox(height: 16.h),

        // 2. Cancellation Alert (If Cancelled)
        if (isCancelled) ...[
          Container(
            padding: EdgeInsets.all(16.r),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.cancel_rounded, color: AppColors.error),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Delivery Cancelled',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.bold,
                          color: AppColors.error,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        'Reason: ${order.cancellationReason ?? 'Shipment halted.'}',
                        style: TextStyle(fontSize: 12.sp),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 14.h),
        ],

        // 3. Waybill Banner & QR Code
        Container(
          padding: EdgeInsets.all(16.r),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => _showWaybillQrModal(context, order),
                child: Container(
                  padding: EdgeInsets.all(4.r),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(10.r),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: QrImageView(
                    data: order.trackingNumber,
                    version: QrVersions.auto,
                    size: 58.r,
                  ),
                ),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CONSIGNMENT WAYBILL',
                      style: TextStyle(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Row(
                      children: [
                        Text(
                          order.trackingNumber,
                          style: TextStyle(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        SizedBox(width: 6.w),
                        InkWell(
                          onTap: () {
                            Clipboard.setData(
                              ClipboardData(text: order.trackingNumber),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Waybill number copied!'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                          child: Icon(
                            Icons.copy_rounded,
                            size: 15.r,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 6.h),
                    Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: 8.w, vertical: 3.h),
                      decoration: BoxDecoration(
                        color: isCancelled
                            ? AppColors.error.withValues(alpha: 0.1)
                            : isDelivered
                                ? AppColors.success.withValues(alpha: 0.1)
                                : AppColors.secondary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6.r),
                      ),
                      child: Text(
                        order.status.label.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.bold,
                          color: isCancelled
                              ? AppColors.error
                              : isDelivered
                                  ? AppColors.success
                                  : AppColors.secondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 14.h),

        // 4. Recipient Security Handover PIN (Fraud Protection Alert)
        Container(
          padding: EdgeInsets.all(16.r),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF3C7), // Amber 100
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: const Color(0xFFF59E0B)),
          ),
          child: Row(
            children: [
              const Icon(Icons.shield_rounded, color: Color(0xFFB45309)),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recipient Verification PIN',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF92400E),
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      'Provide this 4-digit code to the dispatch courier only when the package is handed over to you.',
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: const Color(0xFF78350F),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 10.w),
              Container(
                padding: EdgeInsets.symmetric(
                    horizontal: 10.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(color: const Color(0xFFF59E0B)),
                ),
                child: Text(
                  order.recipientSecurityOtp ?? '----',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 14.h),

        // 5. Visual Progress Stepper
        _buildProgressTimeline(order),
        SizedBox(height: 14.h),

        // 6. Assigned Courier Details (if assigned)
        if (order.driverId != null) ...[
          Container(
            padding: EdgeInsets.all(16.r),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: AppColors.divider),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22.r,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  child: Icon(
                    Icons.directions_bike_rounded,
                    size: 24.r,
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.driverName ?? 'Assigned Courier',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        '${order.vehicleType.label} • Dispatched Rider',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (order.driverPhone != null &&
                    order.driverPhone!.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.phone_rounded,
                        color: AppColors.success),
                    tooltip: 'Call Courier',
                    onPressed: () {
                      _showContactDialog(
                        context,
                        order.driverName ?? 'Courier',
                        order.driverPhone!,
                      );
                    },
                  ),
              ],
            ),
          ),
          SizedBox(height: 14.h),
        ],

        // 7. Route & Destination Details
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
                'Transit Route',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 12.h),
              _buildAddressItem(
                icon: Icons.trip_origin_rounded,
                iconColor: AppColors.success,
                label: 'Origin / Sender Address',
                address: order.pickupLocation.address,
              ),
              Padding(
                padding: EdgeInsets.only(left: 8.w),
                child: SizedBox(
                  height: 16.h,
                  child: const VerticalDivider(
                    color: AppColors.divider,
                    thickness: 2,
                  ),
                ),
              ),
              _buildAddressItem(
                icon: Icons.location_on_rounded,
                iconColor: AppColors.error,
                label: 'Destination / Drop-off Address',
                address: order.dropoffLocation.address,
              ),
            ],
          ),
        ),
        SizedBox(height: 14.h),

        // 8. Package Consignment Specifications (courierManagementSystem logic)
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
                    'Consignment Specifications',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (order.parcel.isFragile)
                    Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: 8.w, vertical: 3.h),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6.r),
                      ),
                      child: Text(
                        'FRAGILE',
                        style: TextStyle(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.bold,
                          color: AppColors.warning,
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(height: 12.h),
              Row(
                children: [
                  _buildSpecMetric(
                    'Physical Weight',
                    '${order.parcel.weightKg.toStringAsFixed(1)} kg',
                  ),
                  _buildSpecMetric(
                    'Volumetric (IATA)',
                    '${order.parcel.volumetricWeightKg.toStringAsFixed(1)} kg',
                  ),
                  _buildSpecMetric(
                    'Billable Weight',
                    '${order.parcel.billableWeightKg.toStringAsFixed(1)} kg',
                  ),
                ],
              ),
              SizedBox(height: 8.h),
              Divider(color: AppColors.divider.withValues(alpha: 0.6)),
              SizedBox(height: 6.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Dimensions (L × W × H)',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    '${order.parcel.lengthCm?.toStringAsFixed(0) ?? '0'} × ${order.parcel.widthCm?.toStringAsFixed(0) ?? '0'} × ${order.parcel.heightCm?.toStringAsFixed(0) ?? '0'} cm',
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: 14.h),

        // 9. Financial Fare Summary
        Container(
          padding: EdgeInsets.all(16.r),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Shipping Fare',
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    '₦${order.pricing.totalFare.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.receipt_long, size: 16),
                label: const Text('View Breakdown'),
                onPressed: () {
                  FareBreakdownBottomSheet.show(context, order);
                },
              ),
            ],
          ),
        ),
        SizedBox(height: 16.h),

        // 10. Share Tracking Link Button
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.secondary,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(vertical: 14.h),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.r),
            ),
          ),
          icon: const Icon(Icons.share_rounded, size: 18),
          label: Text(
            'Share Tracking Link with Recipient',
            style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold),
          ),
          onPressed: () {
            _copyTrackingLink(context, order.trackingNumber);
          },
        ),
        SizedBox(height: 10.h),

        // 11. Report Issue / File Dispute
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textSecondary,
            side: const BorderSide(color: AppColors.divider),
            padding: EdgeInsets.symmetric(vertical: 12.h),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.r),
            ),
          ),
          icon: const Icon(Icons.support_agent_rounded, size: 18),
          label: Text(
            'Report an Issue with this Delivery',
            style: TextStyle(fontSize: 13.sp),
          ),
          onPressed: () {
            FileDisputeModal.show(context, order);
          },
        ),
        SizedBox(height: 24.h),
      ],
    );
  }

  /// Visual Step-by-Step Delivery Progress Stepper
  Widget _buildProgressTimeline(DeliveryOrder order) {
    final status = order.status;
    final isCancelled = status == DeliveryStatus.cancelled;

    final steps = [
      _TimelineStep(
        title: 'Shipment Created',
        subtitle: DateFormat('MMM d, h:mm a').format(order.createdAt),
        isCompleted: true,
        isActive: status == DeliveryStatus.searchingDriver,
      ),
      _TimelineStep(
        title: 'Courier Assigned',
        subtitle: order.driverName != null
            ? '${order.driverName} dispatched'
            : 'Matching nearby fleet rider',
        isCompleted: status != DeliveryStatus.searchingDriver && !isCancelled,
        isActive: status == DeliveryStatus.assigned,
      ),
      _TimelineStep(
        title: 'Package Picked Up',
        subtitle: 'Courier received consignment from sender',
        isCompleted: status == DeliveryStatus.pickedUp ||
            status == DeliveryStatus.inTransit ||
            status == DeliveryStatus.arrivedDropoff ||
            status == DeliveryStatus.delivered,
        isActive: status == DeliveryStatus.arrivedPickup,
      ),
      _TimelineStep(
        title: 'In Transit',
        subtitle: 'En route to recipient destination',
        isCompleted: status == DeliveryStatus.arrivedDropoff ||
            status == DeliveryStatus.delivered,
        isActive: status == DeliveryStatus.inTransit,
      ),
      _TimelineStep(
        title: 'Delivered & Handover Confirmed',
        subtitle: 'Security OTP verified at drop-off',
        isCompleted: status == DeliveryStatus.delivered,
        isActive: status == DeliveryStatus.arrivedDropoff,
      ),
    ];

    return Container(
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
            'Tracking Timeline',
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 14.h),
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
                        width: 22.r,
                        height: 22.r,
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
                          size: 14.r,
                          color: Colors.white,
                        ),
                      ),
                      if (!isLast)
                        Container(
                          width: 2.w,
                          height: 28.h,
                          color: step.isCompleted
                              ? AppColors.success
                              : AppColors.divider,
                        ),
                    ],
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: isLast ? 0 : 14.h),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            step.title,
                            style: TextStyle(
                              fontSize: 13.sp,
                              fontWeight: step.isCompleted || step.isActive
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: step.isCompleted || step.isActive
                                  ? AppColors.textPrimary
                                  : AppColors.textMuted,
                            ),
                          ),
                          Text(
                            step.subtitle,
                            style: TextStyle(
                              fontSize: 11.sp,
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

  Widget _buildAddressItem({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String address,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18.r, color: iconColor),
        SizedBox(width: 10.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.sp,
                  color: AppColors.textSecondary,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                address,
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSpecMetric(String title, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 10.sp,
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            value,
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  void _copyTrackingLink(BuildContext context, String code) {
    final link = 'https://ehailer.app/track/$code';
    Clipboard.setData(ClipboardData(text: link));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.primary,
        content: Text('Tracking link copied to clipboard: $link'),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showWaybillQrModal(BuildContext context, DeliveryOrder order) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (_) {
        return Padding(
          padding: EdgeInsets.all(24.r),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Consignment Waybill QR',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                'Show this barcode at any e-Hailer sorting hub or to the delivery courier.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.sp,
                  color: AppColors.textSecondary,
                ),
              ),
              SizedBox(height: 20.h),
              QrImageView(
                data: order.trackingNumber,
                version: QrVersions.auto,
                size: 180.r,
              ),
              SizedBox(height: 12.h),
              Text(
                order.trackingNumber,
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: AppColors.primary,
                ),
              ),
              SizedBox(height: 16.h),
            ],
          ),
        );
      },
    );
  }

  void _showContactDialog(BuildContext context, String name, String phone) {
    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: Text('Contact $name'),
          content: Text('Courier Phone Number:\n$phone'),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: phone));
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Phone number copied!')),
                );
              },
              child: const Text('Copy Phone'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
          ],
        );
      },
    );
  }
}

class _TimelineStep {
  final String title;
  final String subtitle;
  final bool isCompleted;
  final bool isActive;

  _TimelineStep({
    required this.title,
    required this.subtitle,
    required this.isCompleted,
    required this.isActive,
  });
}
