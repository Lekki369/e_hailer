import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/presentation/styles/app_colors.dart';

class OsmMapWidget extends StatelessWidget {
  final MapController? mapController;
  final LatLng initialCenter;
  final double initialZoom;
  final LatLng? pickupLocation;
  final LatLng? dropoffLocation;
  final LatLng? driverLocation;
  final List<LatLng> routePoints;
  final void Function(TapPosition tapPosition, LatLng point)? onTap;

  const OsmMapWidget({
    super.key,
    this.mapController,
    this.initialCenter = const LatLng(6.5244, 3.3792), // Default (e.g. Lagos)
    this.initialZoom = 13.0,
    this.pickupLocation,
    this.dropoffLocation,
    this.driverLocation,
    this.routePoints = const [],
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        initialCenter: initialCenter,
        initialZoom: initialZoom,
        onTap: onTap,
      ),
      children: [
        // 1. OpenStreetMap Tile Layer (Free, no API key required)
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.ehailer.app',
        ),

        // 2. OSRM Route Polylines
        if (routePoints.isNotEmpty)
          PolylineLayer(
            polylines: [
              Polyline(
                points: routePoints,
                strokeWidth: 4.5,
                color: AppColors.primary,
              ),
            ],
          ),

        // 3. Location & Driver Markers
        MarkerLayer(
          markers: [
            // Pickup Marker
            if (pickupLocation != null)
              Marker(
                point: pickupLocation!,
                width: 44,
                height: 44,
                child: const Icon(
                  Icons.location_on,
                  size: 40,
                  color: AppColors.success,
                ),
              ),

            // Dropoff Marker
            if (dropoffLocation != null)
              Marker(
                point: dropoffLocation!,
                width: 44,
                height: 44,
                child: const Icon(
                  Icons.location_on,
                  size: 40,
                  color: AppColors.error,
                ),
              ),

            // Driver Live Location Marker (from MyOGA & Deliverzler)
            if (driverLocation != null)
              Marker(
                point: driverLocation!,
                width: 46,
                height: 46,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.secondary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.two_wheeler_rounded,
                    size: 26,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
