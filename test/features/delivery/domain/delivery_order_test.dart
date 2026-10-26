import 'package:flutter_test/flutter_test.dart';
import 'package:e_hailer/features/delivery/domain/entities/delivery_order.dart';
import 'package:e_hailer/features/delivery/domain/entities/location_point.dart';
import 'package:e_hailer/features/delivery/domain/entities/parcel_details.dart';
import 'package:e_hailer/features/delivery/domain/entities/pricing_details.dart';
import 'package:e_hailer/features/delivery/domain/value_objects/delivery_status.dart';
import 'package:e_hailer/features/delivery/domain/value_objects/delivery_type.dart';

void main() {
  group('DeliveryStatus Value Object', () {
    test('isOngoing returns true for active steps and false for delivered/cancelled', () {
      expect(DeliveryStatus.created.isOngoing, isTrue);
      expect(DeliveryStatus.searchingDriver.isOngoing, isTrue);
      expect(DeliveryStatus.assigned.isOngoing, isTrue);
      expect(DeliveryStatus.arrivedPickup.isOngoing, isTrue);
      expect(DeliveryStatus.pickedUp.isOngoing, isTrue);
      expect(DeliveryStatus.inTransit.isOngoing, isTrue);
      expect(DeliveryStatus.arrivedDropoff.isOngoing, isTrue);

      expect(DeliveryStatus.delivered.isOngoing, isFalse);
      expect(DeliveryStatus.cancelled.isOngoing, isFalse);
    });

    test('isCompleted returns true only for delivered', () {
      expect(DeliveryStatus.delivered.isCompleted, isTrue);
      expect(DeliveryStatus.created.isCompleted, isFalse);
      expect(DeliveryStatus.cancelled.isCompleted, isFalse);
    });

    test('isCancelled returns true only for cancelled', () {
      expect(DeliveryStatus.cancelled.isCancelled, isTrue);
      expect(DeliveryStatus.delivered.isCancelled, isFalse);
      expect(DeliveryStatus.inTransit.isCancelled, isFalse);
    });
  });

  group('LocationPoint Entity', () {
    const point = LocationPoint(
      latitude: 6.5244,
      longitude: 3.3792,
      address: 'Lagos Island, Lagos',
      contactName: 'Babajide Cole',
      contactPhone: '+2348011112222',
      landmarkOrNote: 'Opposite City Hall',
    );

    test('toMap and fromMap serialize and deserialize properly', () {
      final map = point.toMap();
      final restored = LocationPoint.fromMap(map);

      expect(restored, equals(point));
      expect(restored.latitude, equals(6.5244));
      expect(restored.longitude, equals(3.3792));
      expect(restored.contactName, equals('Babajide Cole'));
      expect(restored.landmarkOrNote, equals('Opposite City Hall'));
    });

    test('copyWith updates specified attributes', () {
      final updated = point.copyWith(
        contactPhone: '+2348099998888',
        landmarkOrNote: 'Near Marina Gate',
      );

      expect(updated.contactPhone, equals('+2348099998888'));
      expect(updated.landmarkOrNote, equals('Near Marina Gate'));
      expect(updated.latitude, equals(6.5244)); // Kept intact
    });
  });

  group('DeliveryOrder Entity', () {
    final now = DateTime(2026, 10, 26, 12, 0, 0);

    const pickup = LocationPoint(
      latitude: 6.5244,
      longitude: 3.3792,
      address: 'Marina, Lagos',
      contactName: 'Sender Dave',
      contactPhone: '+2348012345678',
    );

    const dropoff = LocationPoint(
      latitude: 6.6018,
      longitude: 3.3515,
      address: 'Ikeja, Lagos',
      contactName: 'Receiver Sarah',
      contactPhone: '+2348087654321',
    );

    const parcel = ParcelDetails(
      category: PackageCategory.parcel,
      weightKg: 3.0,
      lengthCm: 30.0,
      widthCm: 20.0,
      heightCm: 15.0,
    );

    const pricing = PricingDetails(
      baseFare: 500.0,
      distanceFare: 1200.0,
      weightSurcharge: 80.0,
      totalFare: 1780.0,
      driverEarnings: 1424.0,
      platformCommission: 356.0,
    );

    final order = DeliveryOrder(
      id: 'ord_12345',
      trackingNumber: 'EH-891023',
      type: DeliveryType.express,
      vehicleType: VehicleType.bike,
      status: DeliveryStatus.searchingDriver,
      customerId: 'cust_abc',
      customerName: 'Dave Okon',
      customerPhone: '+2348012345678',
      pickupLocation: pickup,
      dropoffLocation: dropoff,
      parcel: parcel,
      pricing: pricing,
      distanceKm: 10.0,
      estimatedDurationMinutes: 25,
      createdAt: now,
      recipientSecurityOtp: '4892',
    );

    test('Serialization roundtrip produces exact replica', () {
      final map = order.toMap();
      final restored = DeliveryOrder.fromMap(map);

      expect(restored.id, equals(order.id));
      expect(restored.trackingNumber, equals(order.trackingNumber));
      expect(restored.type, equals(DeliveryType.express));
      expect(restored.vehicleType, equals(VehicleType.bike));
      expect(restored.status, equals(DeliveryStatus.searchingDriver));
      expect(restored.customerId, equals(order.customerId));
      expect(restored.pickupLocation, equals(pickup));
      expect(restored.dropoffLocation, equals(dropoff));
      expect(restored.parcel, equals(parcel));
      expect(restored.pricing, equals(pricing));
      expect(restored.distanceKm, equals(10.0));
      expect(restored.estimatedDurationMinutes, equals(25));
      expect(restored.recipientSecurityOtp, equals('4892'));
    });

    test('fromMap accepts optional docId override', () {
      final map = order.toMap();
      map.remove('id');
      final restored = DeliveryOrder.fromMap(map, 'doc_override_id');

      expect(restored.id, equals('doc_override_id'));
    });

    test('copyWith updates delivery order fields for driver assignment and tracking', () {
      final assignedOrder = order.copyWith(
        status: DeliveryStatus.assigned,
        driverId: 'drv_99',
        driverName: 'Emeka Driver',
        driverPhone: '+2348055556666',
        driverLatitude: 6.5250,
        driverLongitude: 3.3800,
      );

      expect(assignedOrder.status, equals(DeliveryStatus.assigned));
      expect(assignedOrder.driverId, equals('drv_99'));
      expect(assignedOrder.driverName, equals('Emeka Driver'));
      expect(assignedOrder.driverLatitude, equals(6.5250));
      expect(assignedOrder.driverLongitude, equals(3.3800));
      expect(assignedOrder.trackingNumber, equals(order.trackingNumber)); // Preserved
    });

    test('Cancellation attributes update correctly', () {
      final cancelledTime = DateTime(2026, 10, 26, 12, 15, 0);
      final cancelledOrder = order.copyWith(
        status: DeliveryStatus.cancelled,
        cancellationReason: 'Customer changed delivery schedule',
        cancelledByRole: 'customer',
        cancelledAt: cancelledTime,
      );

      expect(cancelledOrder.status, equals(DeliveryStatus.cancelled));
      expect(cancelledOrder.status.isCancelled, isTrue);
      expect(cancelledOrder.cancellationReason, equals('Customer changed delivery schedule'));
      expect(cancelledOrder.cancelledByRole, equals('customer'));
      expect(cancelledOrder.cancelledAt, equals(cancelledTime));
    });

    test('Customer rating and review attributes persist', () {
      final ratedOrder = order.copyWith(
        status: DeliveryStatus.delivered,
        customerRating: 5.0,
        customerReview: 'Fast and cautious delivery!',
      );

      expect(ratedOrder.status, equals(DeliveryStatus.delivered));
      expect(ratedOrder.customerRating, equals(5.0));
      expect(ratedOrder.customerReview, equals('Fast and cautious delivery!'));
    });
  });
}
