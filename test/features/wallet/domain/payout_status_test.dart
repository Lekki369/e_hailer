import 'package:e_hailer/features/wallet/domain/value_objects/payout_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PayoutStatus Value Object Tests', () {
    test('fromString parses valid statuses accurately', () {
      expect(PayoutStatus.fromString('pending'), equals(PayoutStatus.pending));
      expect(PayoutStatus.fromString('approved'), equals(PayoutStatus.approved));
      expect(PayoutStatus.fromString('settled'), equals(PayoutStatus.settled));
      expect(PayoutStatus.fromString('rejected'), equals(PayoutStatus.rejected));
      expect(PayoutStatus.fromString('PENDING'), equals(PayoutStatus.pending));
      expect(PayoutStatus.fromString('SETTLED'), equals(PayoutStatus.settled));
    });

    test('fromString falls back to pending on unknown or null inputs', () {
      expect(PayoutStatus.fromString(null), equals(PayoutStatus.pending));
      expect(PayoutStatus.fromString(''), equals(PayoutStatus.pending));
      expect(PayoutStatus.fromString('unknown_status'), equals(PayoutStatus.pending));
    });

    test('labels match operational specifications', () {
      expect(PayoutStatus.pending.label, equals('Pending Review'));
      expect(PayoutStatus.approved.label, equals('Approved & Processing'));
      expect(PayoutStatus.settled.label, equals('Settled / Transferred'));
      expect(PayoutStatus.rejected.label, equals('Rejected'));
    });
  });
}
