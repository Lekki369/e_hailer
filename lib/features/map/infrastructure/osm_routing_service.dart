import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../../../core/domain/failures/app_failure.dart';
import '../../../core/presentation/utils/fp_framework.dart';
import '../../delivery/domain/entities/location_point.dart';
import '../domain/route_result.dart';

class OsmRoutingService {
  final http.Client _client;
  final Duration timeout;
  final String routeBaseUrl;
  final String geocodeBaseUrl;
  static Future<void> _geocodeQueue = Future.value();
  static DateTime _lastGeocode = DateTime.fromMillisecondsSinceEpoch(0);
  final Map<String, String> _cache = {};
  OsmRoutingService({
    http.Client? client,
    this.timeout = const Duration(seconds: 12),
    this.routeBaseUrl = const String.fromEnvironment(
      'OSRM_BASE_URL',
      defaultValue: 'https://router.project-osrm.org',
    ),
    this.geocodeBaseUrl = const String.fromEnvironment(
      'NOMINATIM_BASE_URL',
      defaultValue: '',
    ),
  }) : _client = client ?? http.Client();
  bool get supportsGeocoding =>
      Uri.tryParse(geocodeBaseUrl)?.hasAuthority == true;
  static bool _valid(LatLng point) =>
      point.latitude.isFinite &&
      point.longitude.isFinite &&
      point.latitude.abs() <= 90 &&
      point.longitude.abs() <= 180;
  static const _headers = {
    'User-Agent': 'e-Hailer/0.1 (courier location selection)',
    'Accept': 'application/json',
  };
  Future<String> _get(Uri url) async {
    final response = await _client.get(url, headers: _headers).timeout(timeout);
    if (response.statusCode != 200) {
      throw const FormatException('Map provider unavailable');
    }
    return response.body;
  }

  Future<String> _geocode(Uri url) async {
    final cached = _cache[url.toString()];
    if (cached != null) return cached;
    final previous = _geocodeQueue;
    final done = Completer<void>();
    _geocodeQueue = done.future;
    await previous;
    try {
      final remaining =
          const Duration(milliseconds: 1100) -
          DateTime.now().difference(_lastGeocode);
      if (remaining > Duration.zero) await Future<void>.delayed(remaining);
      _lastGeocode = DateTime.now();
      final body = await _get(url);
      if (_cache.length >= 50) _cache.remove(_cache.keys.first);
      _cache[url.toString()] = body;
      return body;
    } finally {
      done.complete();
    }
  }

  Future<Either<AppFailure, RouteResult>> getDrivingRoute({
    required LatLng origin,
    required LatLng destination,
  }) async {
    if (!_valid(origin) || !_valid(destination)) {
      return left(
        const ServerFailure(
          message: 'Choose valid pickup and delivery locations.',
        ),
      );
    }
    try {
      final uri = Uri.parse(
        '$routeBaseUrl/route/v1/driving/${origin.longitude},${origin.latitude};${destination.longitude},${destination.latitude}',
      ).replace(queryParameters: {'overview': 'full', 'geometries': 'geojson'});
      final data = jsonDecode(await _get(uri)) as Map<String, dynamic>;
      final routes = data['routes'] as List?;
      if (data['code'] != 'Ok' || routes == null || routes.isEmpty) {
        return left(
          const ServerFailure(
            message:
                'No road route was found. Adjust the locations and try again.',
          ),
        );
      }
      final route = routes.first as Map;
      final distance = (route['distance'] as num).toDouble();
      final duration = (route['duration'] as num).toDouble();
      if (!distance.isFinite ||
          !duration.isFinite ||
          distance <= 0 ||
          duration <= 0) {
        throw const FormatException('Invalid route');
      }
      final points = ((route['geometry'] as Map)['coordinates'] as List).map((
        value,
      ) {
        final pair = value as List;
        final point = LatLng(
          (pair[1] as num).toDouble(),
          (pair[0] as num).toDouble(),
        );
        if (!_valid(point)) throw const FormatException('Invalid coordinate');
        return point;
      }).toList();
      return right(
        RouteResult(
          distanceKm: distance / 1000,
          durationMinutes: (duration / 60).ceil(),
          points: points,
        ),
      );
    } catch (_) {
      return left(
        const NetworkFailure(
          message:
              'Could not calculate a road route. Check your connection and try again.',
        ),
      );
    }
  }

  Future<Either<AppFailure, List<LocationPoint>>> searchPlaces(
    String query,
  ) async {
    if (query.trim().isEmpty) return right(const []);
    try {
      final uri = Uri.parse('$geocodeBaseUrl/search').replace(
        queryParameters: {
          'q': query.trim(),
          'format': 'json',
          'addressdetails': '1',
          'limit': '5',
        },
      );
      final items = jsonDecode(await _geocode(uri)) as List;
      final locations = items.map((item) {
        final point = LatLng(
          double.parse(item['lat'].toString()),
          double.parse(item['lon'].toString()),
        );
        if (!_valid(point)) throw const FormatException('Invalid location');
        return LocationPoint(
          latitude: point.latitude,
          longitude: point.longitude,
          address: item['display_name'] as String,
          contactName: '',
          contactPhone: '',
        );
      }).toList();
      return right(locations);
    } catch (_) {
      return left(
        const NetworkFailure(
          message:
              'Address search is unavailable. Retry or choose a location on the map.',
        ),
      );
    }
  }

  Future<Either<AppFailure, String>> reverseGeocode(LatLng location) async {
    if (!_valid(location)) {
      return left(const ServerFailure(message: 'Choose a valid location.'));
    }
    try {
      final uri = Uri.parse('$geocodeBaseUrl/reverse').replace(
        queryParameters: {
          'lat': '${location.latitude}',
          'lon': '${location.longitude}',
          'format': 'json',
        },
      );
      final data = jsonDecode(await _geocode(uri)) as Map;
      final address = data['display_name'] as String;
      if (address.isEmpty) throw const FormatException('No address');
      return right(address);
    } catch (_) {
      return left(
        const NetworkFailure(
          message:
              'Could not find this address. Add the street address manually.',
        ),
      );
    }
  }

  void dispose() => _client.close();
}
