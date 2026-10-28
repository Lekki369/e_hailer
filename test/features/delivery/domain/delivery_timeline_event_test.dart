import 'package:flutter_test/flutter_test.dart';
import 'package:e_hailer/features/delivery/domain/entities/delivery_timeline_event.dart';
import 'package:e_hailer/features/delivery/domain/value_objects/delivery_status.dart';

void main() {
  group('DeliveryTimelineEvent Entity & Lifecycle Tests', () {
    final testDate = DateTime(2026, 10, 28, 14, 30);
    final event = DeliveryTimelineEvent(
      id: 'EVT-101',
      orderId: 'ORD-999',
      status: DeliveryStatus.pickedUp,
      actorId: 'DRV-123',
      actorRole: 'driver',
      timestamp: testDate,
      note: 'Package collected at sender gate',
      latitude: 6.5244,
      longitude: 3.3792,
    );

    test('toMap and fromMap serialize and restore all properties faithfully', () {
      final map = event.toMap();
      expect(map['id'], 'EVT-101');
      expect(map['orderId'], 'ORD-999');
      expect(map['status'], DeliveryStatus.pickedUp.name);
      expect(map['actorId'], 'DRV-123');
      expect(map['actorRole'], 'driver');
      expect(map['timestamp'], testDate.toIso8601String());
      expect(map['note'], 'Package collected at sender gate');
      expect(map['latitude'], 6.5244);
      expect(map['longitude'], 3.3792);

      final restored = DeliveryTimelineEvent.fromMap(map, 'EVT-101');
      expect(restored, equals(event));
    });

    test('copyWith updates properties selectively', () {
      final updated = event.copyWith(
        status: DeliveryStatus.inTransit,
        note: 'En route to destination',
      );

      expect(updated.id, event.id);
      expect(updated.orderId, event.orderId);
      expect(updated.status, DeliveryStatus.inTransit);
      expect(updated.note, 'En route to destination');
      expect(updated.actorId, event.actorId);
    });

    test('Equatable value equality verification', () {
      final clone = DeliveryTimelineEvent(
        id: 'EVT-101',
        orderId: 'ORD-999',
        status: DeliveryStatus.pickedUp,
        actorId: 'DRV-123',
        actorRole: 'driver',
        timestamp: testDate,
        note: 'Package collected at sender gate',
        latitude: 6.5244,
        longitude: 3.3792,
      );

      expect(event, equals(clone));
    });
  });
}
