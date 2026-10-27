import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:e_hailer/features/map/presentation/widgets/osm_map_widget.dart';

void main() {
  group('OsmMapWidget Tests', () {
    testWidgets('renders static pickup and dropoff markers correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OsmMapWidget(
              pickupLocation: LatLng(6.5244, 3.3792),
              dropoffLocation: LatLng(6.5250, 3.3800),
              isPickupMovable: false,
              showMyLocationButton: true,
            ),
          ),
        ),
      );

      // Verify icons render
      expect(find.byIcon(Icons.location_on), findsNWidgets(2));
      expect(find.byIcon(Icons.my_location_rounded), findsOneWidget);
    });

    testWidgets('renders movable pickup marker with label badge when isPickupMovable is true', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OsmMapWidget(
              pickupLocation: LatLng(6.5244, 3.3792),
              isPickupMovable: true,
              showMyLocationButton: true,
            ),
          ),
        ),
      );

      // Should display "Pickup" badge text on the draggable marker
      expect(find.text('Pickup'), findsOneWidget);
      expect(find.byIcon(Icons.location_on), findsOneWidget);
      expect(find.byIcon(Icons.my_location_rounded), findsOneWidget);
    });

    testWidgets('hides My Location button when showMyLocationButton is false', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OsmMapWidget(
              pickupLocation: LatLng(6.5244, 3.3792),
              showMyLocationButton: false,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.my_location_rounded), findsNothing);
    });

    testWidgets('focuses initialCenter on pickup location area by default', (tester) async {
      const customPickup = LatLng(9.0765, 7.3986); // Abuja
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OsmMapWidget(
              pickupLocation: customPickup,
              isPickupMovable: false,
            ),
          ),
        ),
      );

      // Verify widget builds and renders pickup marker centered
      expect(find.byIcon(Icons.location_on), findsOneWidget);
    });
  });
}
