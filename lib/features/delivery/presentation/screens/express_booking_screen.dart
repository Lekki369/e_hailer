import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/presentation/styles/app_colors.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../map/domain/route_result.dart';
import '../../../map/infrastructure/osm_routing_service.dart';
import '../../../map/presentation/widgets/osm_map_widget.dart';
import '../../domain/entities/delivery_order.dart';
import '../../domain/entities/location_point.dart';
import '../../domain/entities/parcel_details.dart';
import '../../domain/services/pricing_calculator.dart';
import '../../domain/value_objects/delivery_status.dart';
import '../../domain/value_objects/delivery_type.dart';
import '../providers/delivery_providers.dart';

class ExpressBookingScreen extends HookConsumerWidget {
  const ExpressBookingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mapController = useMemoized(() => MapController());
    final routingService = useMemoized(() => OsmRoutingService());

    // Selected locations
    final pickupPoint = useState<LatLng?>(const LatLng(6.5244, 3.3792)); // Lagos center
    final dropoffPoint = useState<LatLng?>(null);
    final pickupAddress = useState<String>('Lagos Island, Lagos');
    final dropoffAddress = useState<String>('Select destination on map');

    // Route info
    final currentRoute = useState<RouteResult?>(null);
    final selectedVehicle = useState<VehicleType>(VehicleType.bike);
    final isLoadingRoute = useState<bool>(false);
    final isSubmitting = useState<bool>(false);

    // Calculate route when both points are set
    Future<void> recalculateRoute(LatLng origin, LatLng dest) async {
      isLoadingRoute.value = true;
      final result = await routingService.getDrivingRoute(
        origin: origin,
        destination: dest,
      );
      isLoadingRoute.value = false;

      result.fold(
        (failure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(failure.message)),
          );
        },
        (route) {
          currentRoute.value = route;
        },
      );
    }

    void handleMapTap(TapPosition tapPosition, LatLng point) async {
      if (dropoffPoint.value == null) {
        dropoffPoint.value = point;
        final addressRes = await routingService.reverseGeocode(point);
        dropoffAddress.value = addressRes.getOrElse((_) => 'Selected Dropoff Point');
        if (pickupPoint.value != null) {
          await recalculateRoute(pickupPoint.value!, point);
        }
      } else {
        // Reset and set as new dropoff
        dropoffPoint.value = point;
        final addressRes = await routingService.reverseGeocode(point);
        dropoffAddress.value = addressRes.getOrElse((_) => 'Selected Dropoff Point');
        if (pickupPoint.value != null) {
          await recalculateRoute(pickupPoint.value!, point);
        }
      }
    }

    // Pricing calculation based on actual road distance
    final distanceKm = currentRoute.value?.distanceKm ?? 3.5;
    final pricing = PricingCalculator.calculate(
      distanceKm: distanceKm,
      parcel: const ParcelDetails(
        category: PackageCategory.parcel,
        weightKg: 2.0,
      ),
      vehicleType: selectedVehicle.value,
    );

    Future<void> handleBookExpress() async {
      final user = ref.read(currentUserProfileProvider).value;
      if (user == null || pickupPoint.value == null || dropoffPoint.value == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select dropoff point on map.')),
        );
        return;
      }

      isSubmitting.value = true;
      final trackingNumber = 'EH-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';

      final order = DeliveryOrder(
        id: '',
        trackingNumber: trackingNumber,
        type: DeliveryType.express,
        vehicleType: selectedVehicle.value,
        status: DeliveryStatus.searchingDriver,
        customerId: user.uid,
        customerName: user.fullName,
        customerPhone: user.phone,
        pickupLocation: LocationPoint(
          latitude: pickupPoint.value!.latitude,
          longitude: pickupPoint.value!.longitude,
          address: pickupAddress.value,
          contactName: user.fullName,
          contactPhone: user.phone,
        ),
        dropoffLocation: LocationPoint(
          latitude: dropoffPoint.value!.latitude,
          longitude: dropoffPoint.value!.longitude,
          address: dropoffAddress.value,
          contactName: 'Recipient',
          contactPhone: '',
        ),
        parcel: const ParcelDetails(
          category: PackageCategory.parcel,
          weightKg: 2.0,
        ),
        pricing: pricing,
        distanceKm: distanceKm,
        estimatedDurationMinutes: currentRoute.value?.durationMinutes ?? 15,
        createdAt: DateTime.now(),
      );

      final result = await ref.read(deliveryRemoteServiceProvider).createOrder(order);
      isSubmitting.value = false;

      result.fold(
        (failure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(failure.message)),
          );
        },
        (created) {
          context.pushReplacement(OrderTrackingRoute.pathWithId(created.id));
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Book Express Dispatch'),
      ),
      body: Stack(
        children: [
          // 1. Interactive OpenStreetMap
          OsmMapWidget(
            mapController: mapController,
            pickupLocation: pickupPoint.value,
            dropoffLocation: dropoffPoint.value,
            routePoints: currentRoute.value?.points ?? const [],
            onTap: handleMapTap,
          ),

          // 2. Instructions Banner
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.touch_app_rounded, color: AppColors.secondary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      dropoffPoint.value == null
                          ? 'Tap anywhere on the map to set dropoff location'
                          : 'Dropoff set: ${dropoffAddress.value}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. Bottom Booking Sheet
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Vehicle Selector
                  Row(
                    children: VehicleType.values.map((v) {
                      final isSelected = selectedVehicle.value == v;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => selectedVehicle.value = v,
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.background,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.divider,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  v == VehicleType.bike
                                      ? Icons.two_wheeler
                                      : v == VehicleType.car
                                          ? Icons.directions_car
                                          : Icons.local_shipping,
                                  color: isSelected ? Colors.white : AppColors.textPrimary,
                                  size: 20,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  v.name.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected ? Colors.white : AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Distance & Price summary
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Estimated Road Distance',
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${distanceKm.toStringAsFixed(1)} km (${currentRoute.value?.durationMinutes ?? 15} mins)',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'Total Fare',
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 2),
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
                  const SizedBox(height: 20),

                  // Submit button
                  ElevatedButton(
                    onPressed: isSubmitting.value ? null : handleBookExpress,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
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
                        : const Text('Confirm & Broadcast Request'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
