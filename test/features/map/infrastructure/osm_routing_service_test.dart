import 'dart:convert';
import 'package:e_hailer/features/map/infrastructure/osm_routing_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';

void main() {
  test(
    'unroutable and malformed responses never become zero-cost routes',
    () async {
      for (final body in [
        '{}',
        '{"code":"NoRoute","routes":[]}',
        '{"code":"Ok","routes":[{"distance":-1,"duration":5}]}',
      ]) {
        final service = OsmRoutingService(
          client: MockClient((_) async => http.Response(body, 200)),
        );
        final result = await service.getDrivingRoute(
          origin: const LatLng(6, 3),
          destination: const LatLng(7, 4),
        );
        expect(result.isLeft(), isTrue);
        service.dispose();
      }
    },
  );
  test(
    'routing converts metres, seconds and GeoJSON coordinate order',
    () async {
      final service = OsmRoutingService(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'code': 'Ok',
              'routes': [
                {
                  'distance': 1500,
                  'duration': 121,
                  'geometry': {
                    'coordinates': [
                      [3, 6],
                      [4, 7],
                    ],
                  },
                },
              ],
            }),
            200,
          ),
        ),
      );
      final result = await service.getDrivingRoute(
        origin: const LatLng(6, 3),
        destination: const LatLng(7, 4),
      );
      result.fold((failure) => fail(failure.message), (route) {
        expect(route.distanceKm, 1.5);
        expect(route.durationMinutes, 3);
        expect(route.points.first, const LatLng(6, 3));
      });
      service.dispose();
    },
  );
  test(
    'provider exceptions produce safe errors without raw request data',
    () async {
      final service = OsmRoutingService(
        client: MockClient(
          (_) async => throw Exception('secret-token-private-address'),
        ),
      );
      final result = await service.getDrivingRoute(
        origin: const LatLng(6, 3),
        destination: const LatLng(7, 4),
      );
      result.fold(
        (failure) => expect(failure.message, isNot(contains('secret-token'))),
        (_) => fail('Expected a failure'),
      );
      service.dispose();
    },
  );
}
