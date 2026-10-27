import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/presentation/styles/app_colors.dart';

class OsmMapWidget extends StatefulWidget {
  final MapController? mapController;

  /// Initial center coordinates. If omitted, defaults to [pickupLocation] area, or Lagos fallback.
  final LatLng? initialCenter;
  final double initialZoom;
  final LatLng? pickupLocation;
  final LatLng? dropoffLocation;
  final LatLng? driverLocation;
  final List<LatLng> routePoints;
  final void Function(TapPosition tapPosition, LatLng point)? onTap;

  /// Whether the pickup pin can be dragged and repositioned interactively
  final bool isPickupMovable;

  /// Automatically fetch user's GPS coordinates and center/set pickup on initial load
  final bool defaultToCurrentLocation;

  /// Automatically focus and center the map camera on the pickup location area
  final bool focusOnPickup;

  /// Display a floating GPS location button to center map and snap pickup to user
  final bool showMyLocationButton;

  /// Triggered whenever the pickup marker position is moved or dropped
  final ValueChanged<LatLng>? onPickupLocationChanged;

  /// Triggered when the user's GPS location is successfully resolved
  final ValueChanged<LatLng>? onMyLocationFound;

  const OsmMapWidget({
    super.key,
    this.mapController,
    this.initialCenter,
    this.initialZoom = 15.0,
    this.pickupLocation,
    this.dropoffLocation,
    this.driverLocation,
    this.routePoints = const [],
    this.onTap,
    this.isPickupMovable = false,
    this.defaultToCurrentLocation = false,
    this.focusOnPickup = true,
    this.showMyLocationButton = true,
    this.onPickupLocationChanged,
    this.onMyLocationFound,
  });

  @override
  State<OsmMapWidget> createState() => _OsmMapWidgetState();
}

class _OsmMapWidgetState extends State<OsmMapWidget> {
  final GlobalKey _mapKey = GlobalKey();
  late final MapController _effectiveMapController;

  LatLng? _currentPickupLocation;
  bool _isDraggingPickup = false;
  bool _isLocatingUser = false;

  /// Resolves the effective initial center defaulting to pickup location area
  LatLng get _effectiveInitialCenter {
    return widget.initialCenter ??
        widget.pickupLocation ??
        _currentPickupLocation ??
        const LatLng(6.5244, 3.3792);
  }

  @override
  void initState() {
    super.initState();
    _effectiveMapController = widget.mapController ?? MapController();
    _currentPickupLocation = widget.pickupLocation;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.defaultToCurrentLocation) {
        _determineAndSetCurrentLocation(
          moveCamera: true,
          updatePickup: true,
        );
      } else if (widget.focusOnPickup && widget.pickupLocation != null) {
        _effectiveMapController.move(widget.pickupLocation!, widget.initialZoom);
      }
    });
  }

  @override
  void didUpdateWidget(covariant OsmMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pickupLocation != oldWidget.pickupLocation && !_isDraggingPickup) {
      _currentPickupLocation = widget.pickupLocation;
      if (widget.focusOnPickup && widget.pickupLocation != null) {
        _effectiveMapController.move(widget.pickupLocation!, widget.initialZoom);
      }
    }
  }

  /// Locates user with Geolocator and optionally moves camera / updates pickup
  Future<void> _determineAndSetCurrentLocation({
    bool moveCamera = true,
    bool updatePickup = true,
  }) async {
    if (_isLocatingUser) return;
    setState(() => _isLocatingUser = true);

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) setState(() => _isLocatingUser = false);
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) setState(() => _isLocatingUser = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) setState(() => _isLocatingUser = false);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      final userLatLng = LatLng(position.latitude, position.longitude);

      if (mounted) {
        if (moveCamera) {
          _effectiveMapController.move(userLatLng, 15.0);
        }

        if (updatePickup) {
          setState(() {
            _currentPickupLocation = userLatLng;
          });
          widget.onPickupLocationChanged?.call(userLatLng);
        }

        widget.onMyLocationFound?.call(userLatLng);
      }
    } catch (e) {
      debugPrint('OsmMapWidget: Failed to retrieve user location: $e');
    } finally {
      if (mounted) {
        setState(() => _isLocatingUser = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectivePickup = _currentPickupLocation ?? widget.pickupLocation;

    return Stack(
      key: _mapKey,
      children: [
        FlutterMap(
          mapController: _effectiveMapController,
          options: MapOptions(
            initialCenter: _effectiveInitialCenter,
            initialZoom: widget.initialZoom,
            onTap: widget.onTap,
            interactionOptions: InteractionOptions(
              flags: _isDraggingPickup ? InteractiveFlag.none : InteractiveFlag.all,
            ),
          ),
          children: [
            // 1. OpenStreetMap Tile Layer (Free raster tiles)
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.ehailer.app',
            ),

            // 2. OSRM Route Polylines
            if (widget.routePoints.isNotEmpty)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: widget.routePoints,
                    strokeWidth: 4.5,
                    color: AppColors.primary,
                  ),
                ],
              ),

            // 3. Markers Layer
            MarkerLayer(
              markers: [
                // Movable / Static Pickup Marker
                if (effectivePickup != null)
                  Marker(
                    point: effectivePickup,
                    width: widget.isPickupMovable ? 76 : 44,
                    height: widget.isPickupMovable ? 72 : 44,
                    alignment: Alignment.topCenter,
                    child: widget.isPickupMovable
                        ? GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onPanStart: (_) {
                              setState(() => _isDraggingPickup = true);
                            },
                            onPanUpdate: (details) {
                              final renderBox = _mapKey.currentContext?.findRenderObject() as RenderBox?;
                              if (renderBox != null) {
                                final localOffset = renderBox.globalToLocal(details.globalPosition);
                                final newLatLng = _effectiveMapController.camera.screenOffsetToLatLng(localOffset);
                                setState(() {
                                  _currentPickupLocation = newLatLng;
                                });
                                widget.onPickupLocationChanged?.call(newLatLng);
                              }
                            },
                            onPanEnd: (_) {
                              setState(() => _isDraggingPickup = false);
                              if (_currentPickupLocation != null) {
                                widget.onPickupLocationChanged?.call(_currentPickupLocation!);
                              }
                            },
                            onPanCancel: () {
                              setState(() => _isDraggingPickup = false);
                            },
                            child: _buildMovablePickupMarkerChild(),
                          )
                        : const Icon(
                            Icons.location_on,
                            size: 40,
                            color: AppColors.success,
                          ),
                  ),

                // Dropoff Marker
                if (widget.dropoffLocation != null)
                  Marker(
                    point: widget.dropoffLocation!,
                    width: 44,
                    height: 44,
                    alignment: Alignment.topCenter,
                    child: const Icon(
                      Icons.location_on,
                      size: 40,
                      color: AppColors.error,
                    ),
                  ),

                // Driver Live Location Marker
                if (widget.driverLocation != null)
                  Marker(
                    point: widget.driverLocation!,
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
        ),

        // 4. "My Location" Floating GPS Action Button
        if (widget.showMyLocationButton)
          Positioned(
            right: 16,
            bottom: 16,
            child: Material(
              color: Colors.white,
              elevation: 4,
              shadowColor: Colors.black.withValues(alpha: 0.25),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => _determineAndSetCurrentLocation(
                  moveCamera: true,
                  updatePickup: widget.isPickupMovable,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: _isLocatingUser
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: AppColors.primary,
                          ),
                        )
                      : const Icon(
                          Icons.my_location_rounded,
                          size: 22,
                          color: AppColors.primary,
                        ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Visual presentation of the movable pickup pin with dragging feedback
  Widget _buildMovablePickupMarkerChild() {
    return AnimatedScale(
      duration: const Duration(milliseconds: 150),
      scale: _isDraggingPickup ? 1.15 : 1.0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Dragging badge indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _isDraggingPickup ? AppColors.primary : AppColors.success,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              _isDraggingPickup ? 'Moving...' : 'Pickup',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 2),
          // Pin icon with lift shadow
          Icon(
            Icons.location_on,
            size: 38,
            color: _isDraggingPickup ? AppColors.primary : AppColors.success,
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: _isDraggingPickup ? 0.35 : 0.15),
                blurRadius: _isDraggingPickup ? 8 : 4,
                offset: Offset(0, _isDraggingPickup ? 6 : 2),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
