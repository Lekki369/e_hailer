import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../../core/domain/failures/app_failure.dart';
import '../../../core/presentation/utils/fp_framework.dart';
import '../../delivery/domain/entities/location_point.dart';
import '../domain/route_result.dart';

class OsmRoutingService {
  final http.Client _client;

  OsmRoutingService({http.Client? client}) : _client = client ?? http.Client();

  /// Calculates driving route and polyline coordinates using OSRM (Open Source Routing Machine)
  Future<Either<AppFailure, RouteResult>> getDrivingRoute({
    required LatLng origin,
    required LatLng destination,
  }) async {
    try {
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${origin.longitude},${origin.latitude};${destination.longitude},${destination.latitude}'
        '?overview=full&geometries=geojson',
      );

      final response = await _client.get(
        url,
        headers: {'User-Agent': 'e_hailer_flutter_logistics_app'},
      );

      if (response.statusCode != 200) {
        return left(ServerFailure(
          message: 'Failed to calculate route. Status: ${response.statusCode}',
        ));
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final routes = data['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) {
        return left(const ServerFailure(message: 'No route found between locations.'));
      }

      final primaryRoute = routes.first as Map<String, dynamic>;
      final distanceMeters = (primaryRoute['distance'] as num?)?.toDouble() ?? 0.0;
      final durationSeconds = (primaryRoute['duration'] as num?)?.toDouble() ?? 0.0;

      final geometry = primaryRoute['geometry'] as Map<String, dynamic>?;
      final rawCoordinates = geometry?['coordinates'] as List<dynamic>? ?? [];

      final points = rawCoordinates.map((coord) {
        final pair = coord as List<dynamic>;
        // GeoJSON uses [longitude, latitude]
        final lng = (pair[0] as num).toDouble();
        final lat = (pair[1] as num).toDouble();
        return LatLng(lat, lng);
      }).toList();

      return right(RouteResult(
        distanceKm: distanceMeters / 1000.0,
        durationMinutes: (durationSeconds / 60.0).round(),
        points: points,
      ));
    } catch (e) {
      return left(ServerFailure(message: 'OSRM routing failed: $e'));
    }
  }

  /// Searches for places/addresses using OpenStreetMap Nominatim
  Future<Either<AppFailure, List<LocationPoint>>> searchPlaces(
      String query) async {
    if (query.trim().isEmpty) return right(const []);

    try {
      final encodedQuery = Uri.encodeComponent(query.trim());
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=$encodedQuery&format=json&addressdetails=1&limit=5',
      );

      final response = await _client.get(
        url,
        headers: {'User-Agent': 'e_hailer_flutter_logistics_app'},
      );

      if (response.statusCode != 200) {
        return left(ServerFailure(
          message: 'Nominatim search error: ${response.statusCode}',
        ));
      }

      final list = jsonDecode(response.body) as List<dynamic>;
      final results = list.map((item) {
        final map = item as Map<String, dynamic>;
        final lat = double.tryParse(map['lat'].toString()) ?? 0.0;
        final lon = double.tryParse(map['lon'].toString()) ?? 0.0;
        final displayName = map['display_name'] as String? ?? '';

        return LocationPoint(
          latitude: lat,
          longitude: lon,
          address: displayName,
          contactName: '',
          contactPhone: '',
        );
      }).toList();

      return right(results);
    } catch (e) {
      return left(ServerFailure(message: 'Nominatim search failed: $e'));
    }
  }

  /// Reverse geocodes LatLng into a human-readable street address
  Future<Either<AppFailure, String>> reverseGeocode(LatLng location) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?lat=${location.latitude}&lon=${location.longitude}&format=json',
      );

      final response = await _client.get(
        url,
        headers: {'User-Agent': 'e_hailer_flutter_logistics_app'},
      );

      if (response.statusCode != 200) {
        return left(ServerFailure(
          message: 'Reverse geocode failed: ${response.statusCode}',
        ));
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final displayName = data['display_name'] as String? ?? 'Pinned Location';
      return right(displayName);
    } catch (e) {
      return left(ServerFailure(message: 'Reverse geocode failed: $e'));
    }
  }
}
