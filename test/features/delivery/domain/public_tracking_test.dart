import 'package:e_hailer/core/routing/app_routes.dart';
import 'package:e_hailer/features/delivery/domain/value_objects/delivery_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Public Tracking & Waybill Tests', () {
    test('publicTracking route helper generates correct URLs', () {
      expect(AppRoutes.publicTrackingPath, equals('/track'));
      expect(AppRoutes.publicTrackingName, equals('public-tracking'));
      expect(
        AppRoutes.publicTracking('WAYBILL-20261026-8910'),
        equals('/track/WAYBILL-20261026-8910'),
      );
      expect(
        DeliveryRoutes.publicTracking('EH-998877'),
        equals('/track/EH-998877'),
      );
    });

    test('Tracking code normalization strips whitespace and converts to uppercase', () {
      const rawInput = '   waybill-abc-123   ';
      final normalized = rawInput.trim().toUpperCase();
      expect(normalized, equals('WAYBILL-ABC-123'));
    });

    test('DeliveryStatus labels map to customer-friendly progress states', () {
      expect(DeliveryStatus.created.label, equals('Order Placed'));
      expect(DeliveryStatus.searchingDriver.label, equals('Finding Nearby Driver'));
      expect(DeliveryStatus.assigned.label, equals('Driver Assigned'));
      expect(DeliveryStatus.arrivedPickup.label, equals('Driver Arrived at Pickup'));
      expect(DeliveryStatus.pickedUp.label, equals('Package Picked Up'));
      expect(DeliveryStatus.inTransit.label, equals('In Transit to Destination'));
      expect(DeliveryStatus.arrivedDropoff.label, equals('Arrived at Destination'));
      expect(DeliveryStatus.delivered.label, equals('Delivered'));
      expect(DeliveryStatus.cancelled.label, equals('Cancelled'));
    });

    test('DeliveryStatus ongoing determination matches delivery steps', () {
      expect(DeliveryStatus.searchingDriver.isOngoing, isTrue);
      expect(DeliveryStatus.assigned.isOngoing, isTrue);
      expect(DeliveryStatus.inTransit.isOngoing, isTrue);
      expect(DeliveryStatus.arrivedDropoff.isOngoing, isTrue);
      expect(DeliveryStatus.delivered.isOngoing, isFalse);
      expect(DeliveryStatus.cancelled.isOngoing, isFalse);
    });
  });
}
