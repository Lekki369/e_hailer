import 'package:flutter_test/flutter_test.dart';
import 'package:e_hailer/features/delivery/domain/value_objects/delivery_status.dart';

void main() {
  group('DeliveryStatus State Machine & Lifecycle Transitions', () {
    test('Legal sequential forward lifecycle transitions', () {
      expect(
          DeliveryStatus.created.canTransitionTo(DeliveryStatus.searchingDriver),
          isTrue);
      expect(
          DeliveryStatus.searchingDriver
              .canTransitionTo(DeliveryStatus.assigned),
          isTrue);
      expect(
          DeliveryStatus.assigned.canTransitionTo(DeliveryStatus.arrivedPickup),
          isTrue);
      expect(
          DeliveryStatus.arrivedPickup.canTransitionTo(DeliveryStatus.pickedUp),
          isTrue);
      expect(
          DeliveryStatus.arrivedPickup.canTransitionTo(DeliveryStatus.inTransit),
          isTrue);
      expect(
          DeliveryStatus.pickedUp.canTransitionTo(DeliveryStatus.inTransit),
          isTrue);
      expect(
          DeliveryStatus.inTransit
              .canTransitionTo(DeliveryStatus.arrivedDropoff),
          isTrue);
      expect(
          DeliveryStatus.inTransit.canTransitionTo(DeliveryStatus.delivered),
          isTrue);
      expect(
          DeliveryStatus.arrivedDropoff
              .canTransitionTo(DeliveryStatus.delivered),
          isTrue);
    });

    test('Identical status transition is always legal (idempotent)', () {
      for (final status in DeliveryStatus.values) {
        expect(status.canTransitionTo(status), isTrue);
      }
    });

    test('Illegal status jumps are strictly prohibited for drivers & users', () {
      // Cannot jump straight from created to delivered
      expect(
          DeliveryStatus.created.canTransitionTo(DeliveryStatus.delivered),
          isFalse);
      // Cannot jump from searchingDriver directly to delivered
      expect(
          DeliveryStatus.searchingDriver
              .canTransitionTo(DeliveryStatus.delivered),
          isFalse);
      // Cannot jump backwards from delivered to inTransit
      expect(
          DeliveryStatus.delivered.canTransitionTo(DeliveryStatus.inTransit),
          isFalse);
      // Cannot revive a delivered order
      expect(
          DeliveryStatus.delivered.canTransitionTo(DeliveryStatus.assigned),
          isFalse);
      // Cannot transition from cancelled
      expect(
          DeliveryStatus.cancelled.canTransitionTo(DeliveryStatus.inTransit),
          isFalse);
      // Cannot jump from assigned directly to delivered without pickup
      expect(
          DeliveryStatus.assigned.canTransitionTo(DeliveryStatus.delivered),
          isFalse);
    });

    test('Admin exceptional overrides', () {
      // Admin can cancel an order at any active point
      expect(
          DeliveryStatus.assigned
              .canTransitionTo(DeliveryStatus.cancelled, isAdmin: true),
          isTrue);
      expect(
          DeliveryStatus.inTransit
              .canTransitionTo(DeliveryStatus.cancelled, isAdmin: true),
          isTrue);

      // Admin can return failed deliveries or problematic transit to hub
      expect(
          DeliveryStatus.inTransit
              .canTransitionTo(DeliveryStatus.returnedToHub, isAdmin: true),
          isTrue);

      // Admin can reassign from searching or active state
      expect(
          DeliveryStatus.searchingDriver
              .canTransitionTo(DeliveryStatus.assigned, isAdmin: true),
          isTrue);
    });
  });
}
