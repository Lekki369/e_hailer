import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../infrastructure/driver_location_broadcast_service.dart';
import '../../infrastructure/osm_routing_service.dart';

/// Provider for OSRM Road Routing and Nominatim Geocoding
final osmRoutingServiceProvider = Provider<OsmRoutingService>((ref) {
  return OsmRoutingService();
});

/// Provider for Live Driver GPS Broadcast Service
final driverLocationBroadcastServiceProvider =
    Provider<DriverLocationBroadcastService>((ref) {
  return DriverLocationBroadcastService();
});
