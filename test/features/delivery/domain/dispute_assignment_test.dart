import 'package:flutter_test/flutter_test.dart';
import 'package:e_hailer/features/delivery/domain/entities/delivery_dispute.dart';
import 'package:e_hailer/features/delivery/domain/value_objects/dispute_category.dart';
import 'package:e_hailer/features/delivery/domain/value_objects/dispute_status.dart';

void main() {
  group('DeliveryDispute Support Agent Assignment Tests', () {
    final dispute = DeliveryDispute(
      id: 'DISP-77',
      orderId: 'ORD-123',
      trackingNumber: 'WAYBILL-9900',
      claimantId: 'CUST-55',
      claimantName: 'John Sender',
      claimantRole: 'customer',
      claimantPhone: '+234800000000',
      category: DisputeCategory.damagedItem,
      description: 'Package carton was wet and dented on arrival',
      status: DisputeStatus.open,
      createdAt: DateTime(2026, 10, 28, 10, 0),
    );

    test('Initial dispute is unassigned', () {
      expect(dispute.assignedAgentId, isNull);
      expect(dispute.assignedAgentName, isNull);
    });

    test('Assigning support agent updates state and serializes correctly', () {
      final assigned = dispute.copyWith(
        assignedAgentId: 'SUPP-404',
        assignedAgentName: 'Officer Deborah',
        status: DisputeStatus.underInvestigation,
      );

      expect(assigned.assignedAgentId, 'SUPP-404');
      expect(assigned.assignedAgentName, 'Officer Deborah');
      expect(assigned.status, DisputeStatus.underInvestigation);

      final map = assigned.toMap();
      expect(map['assignedAgentId'], 'SUPP-404');
      expect(map['assignedAgentName'], 'Officer Deborah');

      final restored = DeliveryDispute.fromMap(map, 'DISP-77');
      expect(restored.assignedAgentId, 'SUPP-404');
      expect(restored.assignedAgentName, 'Officer Deborah');
      expect(restored, equals(assigned));
    });
  });
}
