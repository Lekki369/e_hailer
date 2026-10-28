import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/presentation/styles/app_colors.dart';
import '../../../delivery/domain/entities/delivery_order.dart';
import '../../../delivery/domain/value_objects/delivery_status.dart';
import '../../domain/entities/fleet_driver_summary.dart';
import '../providers/admin_providers.dart';
import '../widgets/manual_assignment_modal.dart';

/// Interactive operations map rendering real-time fleet driver GPS coordinates,
/// active pickup & dropoff waypoints, and geofence operational zones using OpenStreetMap.
class AdminMapOverviewScreen extends StatefulHookConsumerWidget {
  const AdminMapOverviewScreen({super.key});

  @override
  ConsumerState<AdminMapOverviewScreen> createState() =>
      _AdminMapOverviewScreenState();
}

class _AdminMapOverviewScreenState
    extends ConsumerState<AdminMapOverviewScreen> {
  late final MapController _mapController;
  FleetDriverSummary? _selectedDriver;
  DeliveryOrder? _selectedOrder;
  bool _showDropoffs = true;
  bool _showGeofences = true;

  // Major operational dispatch zones / geofences
  static final List<_DispatchZone> _zones = [
    _DispatchZone(
      name: 'Ikeja Hub Zone',
      center: const LatLng(6.5950, 3.3550),
      radiusMeters: 4500,
      color: Colors.blue,
    ),
    _DispatchZone(
      name: 'Island & Lekki Zone',
      center: const LatLng(6.4474, 3.4723),
      radiusMeters: 5500,
      color: Colors.purple,
    ),
    _DispatchZone(
      name: 'Mainland Yaba Zone',
      center: const LatLng(6.5080, 3.3750),
      radiusMeters: 4000,
      color: Colors.teal,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final drivers = ref.watch(onlineFleetDriversProvider);
    final ordersAsync = ref.watch(allOrdersStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Fleet Map Operations',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              _showGeofences ? Icons.layers : Icons.layers_clear,
              color: _showGeofences ? AppColors.primary : Colors.grey,
            ),
            tooltip: 'Toggle Zone Geofences',
            onPressed: () {
              setState(() {
                _showGeofences = !_showGeofences;
              });
            },
          ),
          IconButton(
            icon: Icon(
              _showDropoffs ? Icons.pin_drop : Icons.pin_drop_outlined,
              color: _showDropoffs ? Colors.red : Colors.grey,
            ),
            tooltip: 'Toggle Dropoffs',
            onPressed: () {
              setState(() {
                _showDropoffs = !_showDropoffs;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.my_location),
            tooltip: 'Recenter Lagos Hub',
            onPressed: () {
              _mapController.move(const LatLng(6.5244, 3.3792), 12.0);
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // OpenStreetMap Layer
          ordersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Map error: $err')),
            data: (allOrders) {
              final activeOrders = allOrders
                  .where((o) =>
                      o.status != DeliveryStatus.delivered &&
                      o.status != DeliveryStatus.cancelled)
                  .toList();

              final markers = <Marker>[];

              // 1. Add Driver markers
              for (final driver in drivers) {
                if (driver.lastKnownLatitude != null &&
                    driver.lastKnownLongitude != null) {
                  final pos = LatLng(
                    driver.lastKnownLatitude!,
                    driver.lastKnownLongitude!,
                  );
                  markers.add(
                    Marker(
                      point: pos,
                      width: 44.w,
                      height: 44.w,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedDriver = driver;
                            _selectedOrder = null;
                          });
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.green.shade600,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.two_wheeler,
                            color: Colors.white,
                            size: 22.w,
                          ),
                        ),
                      ),
                    ),
                  );
                }
              }

              // 2. Add Active Order Pickup Markers
              for (final order in activeOrders) {
                final pos = LatLng(
                  order.pickupLocation.latitude,
                  order.pickupLocation.longitude,
                );
                final isUnassigned = order.driverId == null;

                markers.add(
                  Marker(
                    point: pos,
                    width: 38.w,
                    height: 38.w,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedOrder = order;
                          _selectedDriver = null;
                        });
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isUnassigned
                              ? Colors.orange.shade800
                              : AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 5,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.inventory_2,
                          color: Colors.white,
                          size: 18.w,
                        ),
                      ),
                    ),
                  ),
                );

                // 3. Add Dropoff Marker if enabled
                if (_showDropoffs) {
                  final dropPos = LatLng(
                    order.dropoffLocation.latitude,
                    order.dropoffLocation.longitude,
                  );
                  markers.add(
                    Marker(
                      point: dropPos,
                      width: 32.w,
                      height: 32.w,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedOrder = order;
                            _selectedDriver = null;
                          });
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.red.shade700,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          child: Icon(
                            Icons.location_on,
                            color: Colors.white,
                            size: 18.w,
                          ),
                        ),
                      ),
                    ),
                  );
                }
              }

              // Geofence Circle Markers
              final circleMarkers = <CircleMarker>[];
              if (_showGeofences) {
                for (final zone in _zones) {
                  circleMarkers.add(
                    CircleMarker(
                      point: zone.center,
                      radius: zone.radiusMeters,
                      useRadiusInMeter: true,
                      color: zone.color.withValues(alpha: 0.10),
                      borderColor: zone.color.withValues(alpha: 0.6),
                      borderStrokeWidth: 2.0,
                    ),
                  );
                }
              }

              return FlutterMap(
                mapController: _mapController,
                options: const MapOptions(
                  initialCenter: LatLng(6.5244, 3.3792), // Lagos default
                  initialZoom: 12.0,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.ehailer.app',
                  ),
                  if (_showGeofences) CircleLayer(circles: circleMarkers),
                  MarkerLayer(markers: markers),
                ],
              );
            },
          ),

          // Map Legend / Counter Overlay
          Positioned(
            top: 16.h,
            left: 16.w,
            right: 16.w,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(12.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 10.w,
                          height: 10.w,
                          decoration: BoxDecoration(
                            color: Colors.green.shade600,
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: 6.w),
                        Text(
                          '${drivers.length} Drivers',
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(width: 14.w),
                    Row(
                      children: [
                        Container(
                          width: 10.w,
                          height: 10.w,
                          decoration: BoxDecoration(
                            color: Colors.orange.shade800,
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: 6.w),
                        Text(
                          'Pickups',
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(width: 14.w),
                    Row(
                      children: [
                        Container(
                          width: 10.w,
                          height: 10.w,
                          decoration: BoxDecoration(
                            color: Colors.red.shade700,
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: 6.w),
                        Text(
                          'Dropoffs',
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(width: 14.w),
                    Row(
                      children: [
                        Container(
                          width: 10.w,
                          height: 10.w,
                          decoration: BoxDecoration(
                            color: Colors.purple.shade400,
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: 6.w),
                        Text(
                          'Zones',
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Selection Details Bottom Card
          if (_selectedDriver != null)
            Positioned(
              bottom: 24.h,
              left: 16.w,
              right: 16.w,
              child: _buildDriverPopup(_selectedDriver!),
            )
          else if (_selectedOrder != null)
            Positioned(
              bottom: 24.h,
              left: 16.w,
              right: 16.w,
              child: _buildOrderPopup(_selectedOrder!),
            ),
        ],
      ),
    );
  }

  Widget _buildDriverPopup(FleetDriverSummary driver) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                driver.fullName,
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => setState(() => _selectedDriver = null),
              ),
            ],
          ),
          SizedBox(height: 4.h),
          Text(
            '${driver.vehicleType.label} • ${driver.vehiclePlateNumber ?? "No Plate"} • ⭐ ${driver.rating.toStringAsFixed(1)}',
            style: TextStyle(fontSize: 12.sp, color: AppColors.textSecondary),
          ),
          SizedBox(height: 10.h),
          Text(
            driver.phone,
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderPopup(DeliveryOrder order) {
    final isUnassigned = order.driverId == null;

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    'Waybill: ${order.trackingNumber}',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 6.w,
                      vertical: 2.h,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(6.r),
                    ),
                    child: Text(
                      order.pickupZone,
                      style: TextStyle(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => setState(() => _selectedOrder = null),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          Text(
            'Pickup: ${order.pickupLocation.address}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12.sp, color: AppColors.textPrimary),
          ),
          SizedBox(height: 2.h),
          Text(
            'Dropoff: ${order.dropoffLocation.address}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12.sp, color: AppColors.textSecondary),
          ),
          SizedBox(height: 12.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: Icon(
                isUnassigned ? Icons.person_add : Icons.sync,
                size: 16.w,
              ),
              label: Text(
                isUnassigned ? 'Assign Driver Now' : 'Reassign Driver',
              ),
              onPressed: () {
                ManualAssignmentModal.show(context, order);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DispatchZone {
  final String name;
  final LatLng center;
  final double radiusMeters;
  final Color color;

  const _DispatchZone({
    required this.name,
    required this.center,
    required this.radiusMeters,
    required this.color,
  });
}
