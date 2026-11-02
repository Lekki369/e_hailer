import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../../../core/domain/operation_failure.dart';
import '../domain/road_route.dart';

class OsrmRouteService {
  final http.Client client;
  final String baseUrl;
  OsrmRouteService({
    required this.client,
    this.baseUrl = 'https://router.project-osrm.org',
  });
  Future<RoadRoute> lookup(Json pickup, Json dropoff) async {
    try {
      final uri = Uri.parse(
        '$baseUrl/route/v1/driving/${pickup['longitude']},${pickup['latitude']};${dropoff['longitude']},${dropoff['latitude']}?overview=false',
      );
      final response = await client
          .get(uri)
          .timeout(const Duration(seconds: 12));
      requireCondition(
        response.statusCode == 200,
        'Road routing is temporarily unavailable.',
        'route-unavailable',
      );
      final data = jsonDecode(response.body) as Json;
      final routes = data['routes'] as List? ?? [];
      requireCondition(
        data['code'] == 'Ok' && routes.isNotEmpty,
        'No road route was found between these locations.',
      );
      final route = routes.first as Json;
      return RoadRoute(
        finiteNumber(
          (route['distance'] as num) / 1000,
          0.01,
          5000,
          'road distance',
        ),
        max(
          1,
          (finiteNumber(route['duration'], 0, 604800, 'duration') / 60).round(),
        ),
      );
    } on OperationFailure {
      rethrow;
    } catch (_) {
      throw const OperationFailure(
        'route-unavailable',
        'Could not calculate a road route. Please retry.',
      );
    }
  }
}
