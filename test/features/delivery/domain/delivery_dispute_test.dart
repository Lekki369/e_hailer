import 'package:e_hailer/features/delivery/domain/entities/delivery_dispute.dart';
import 'package:e_hailer/features/delivery/domain/value_objects/dispute_category.dart';
import 'package:e_hailer/features/delivery/domain/value_objects/dispute_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DeliveryDispute Entity Tests', () {
    test('toMap and fromMap serialize and restore all properties cleanly', () {
      final dispute = DeliveryDispute(
        id: 'disp-001',
        orderId: 'ord-777',
        trackingNumber: 'WAYBILL-20261026-7777',
        claimantId: 'usr-customer-1',
        claimantName: 'Kemi Adeyemi',
        claimantRole: 'customer',
        claimantPhone: '+2348012345678',
        category: DisputeCategory.damagedItem,
        description: 'Package arrived with torn outer box and shattered bottle.',
        evidenceNotes: 'Photos presented to courier.',
        status: DisputeStatus.open,
        createdAt: DateTime(2026, 10, 26, 14, 0, 0),
        resolvedAt: null,
        resolvedBy: null,
        resolutionNotes: null,
        refundAmount: null,
        returnTrackingNumber: null,
      );

      final map = dispute.toMap();
      final replica = DeliveryDispute.fromMap(map, dispute.id);

      expect(replica.id, equals(dispute.id));
      expect(replica.orderId, equals(dispute.orderId));
      expect(replica.trackingNumber, equals(dispute.trackingNumber));
      expect(replica.claimantId, equals(dispute.claimantId));
      expect(replica.claimantName, equals(dispute.claimantName));
      expect(replica.claimantRole, equals('customer'));
      expect(replica.category, equals(DisputeCategory.damagedItem));
      expect(replica.description, equals(dispute.description));
      expect(replica.evidenceNotes, equals(dispute.evidenceNotes));
      expect(replica.status, equals(DisputeStatus.open));
      expect(replica.createdAt, equals(dispute.createdAt));
      expect(replica.resolvedAt, isNull);
    });

    test('fromMap parses resolved dispute with refund amount and arbitrator', () {
      final resolvedTime = DateTime(2026, 10, 26, 16, 30, 0);
      final map = {
        'orderId': 'ord-888',
        'trackingNumber': 'WAYBILL-20261026-8888',
        'claimantId': 'usr-drv-2',
        'claimantName': 'Tunde Balogun',
        'claimantRole': 'driver',
        'claimantPhone': '+2348099998888',
        'category': 'unreachableRecipient',
        'description': 'Recipient phone unreachable after 3 attempts at gate.',
        'evidenceNotes': 'Gate security confirmed recipient is not home.',
        'status': 'resolvedRefund',
        'createdAt': '2026-10-26T15:00:00.000',
        'resolvedAt': resolvedTime.toIso8601String(),
        'resolvedBy': 'Lead Dispatcher',
        'resolutionNotes': 'Customer approved full refund.',
        'refundAmount': 3200.0,
        'returnTrackingNumber': 'RET-WAYBILL-8888',
      };

      final dispute = DeliveryDispute.fromMap(map, 'disp-002');

      expect(dispute.id, equals('disp-002'));
      expect(dispute.category, equals(DisputeCategory.unreachableRecipient));
      expect(dispute.status, equals(DisputeStatus.resolvedRefund));
      expect(dispute.resolvedAt, equals(resolvedTime));
      expect(dispute.resolvedBy, equals('Lead Dispatcher'));
      expect(dispute.refundAmount, equals(3200.0));
      expect(dispute.returnTrackingNumber, equals('RET-WAYBILL-8888'));
    });

    test('copyWith updates fields without mutating original instance', () {
      final initial = DeliveryDispute(
        id: 'disp-003',
        orderId: 'ord-333',
        trackingNumber: 'WAYBILL-3333',
        claimantId: 'c-1',
        claimantName: 'Amina',
        claimantRole: 'customer',
        claimantPhone: '+2348000000000',
        category: DisputeCategory.fareDispute,
        description: 'Overcharge query',
        status: DisputeStatus.open,
        createdAt: DateTime(2026, 10, 26, 9, 0, 0),
      );

      final updated = initial.copyWith(
        status: DisputeStatus.resolvedRefund,
        refundAmount: 500.0,
        resolutionNotes: 'Adjusted fare error.',
      );

      expect(updated.status, equals(DisputeStatus.resolvedRefund));
      expect(updated.refundAmount, equals(500.0));
      expect(updated.resolutionNotes, equals('Adjusted fare error.'));
      expect(initial.status, equals(DisputeStatus.open));
      expect(initial.refundAmount, isNull);
    });

    test('Equatable value equality verification', () {
      final date = DateTime(2026, 10, 26, 12, 0, 0);
      final d1 = DeliveryDispute(
        id: 'same-id',
        orderId: 'ord-1',
        trackingNumber: 'TRK-1',
        claimantId: 'c-1',
        claimantName: 'Name',
        claimantRole: 'customer',
        claimantPhone: '123',
        category: DisputeCategory.other,
        description: 'Test',
        createdAt: date,
      );

      final d2 = DeliveryDispute(
        id: 'same-id',
        orderId: 'ord-1',
        trackingNumber: 'TRK-1',
        claimantId: 'c-1',
        claimantName: 'Name',
        claimantRole: 'customer',
        claimantPhone: '123',
        category: DisputeCategory.other,
        description: 'Test',
        createdAt: date,
      );

      expect(d1, equals(d2));
      expect(d1.hashCode, equals(d2.hashCode));
    });
  });
}
