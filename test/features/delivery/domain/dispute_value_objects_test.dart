import 'package:e_hailer/features/delivery/domain/value_objects/dispute_category.dart';
import 'package:e_hailer/features/delivery/domain/value_objects/dispute_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DisputeCategory Value Object Tests', () {
    test('fromString parses valid dispute categories accurately', () {
      expect(
        DisputeCategory.fromString('damagedItem'),
        equals(DisputeCategory.damagedItem),
      );
      expect(
        DisputeCategory.fromString('missingItem'),
        equals(DisputeCategory.missingItem),
      );
      expect(
        DisputeCategory.fromString('unreachableRecipient'),
        equals(DisputeCategory.unreachableRecipient),
      );
      expect(
        DisputeCategory.fromString('wrongAddress'),
        equals(DisputeCategory.wrongAddress),
      );
      expect(
        DisputeCategory.fromString('fareDispute'),
        equals(DisputeCategory.fareDispute),
      );
      expect(
        DisputeCategory.fromString('packageRefused'),
        equals(DisputeCategory.packageRefused),
      );
    });

    test('fromString fallback maps to other for null or unknown categories', () {
      expect(DisputeCategory.fromString(null), equals(DisputeCategory.other));
      expect(DisputeCategory.fromString(''), equals(DisputeCategory.other));
      expect(DisputeCategory.fromString('invalid_cat'), equals(DisputeCategory.other));
    });

    test('labels are descriptive and professional', () {
      expect(DisputeCategory.damagedItem.label,
          equals('Damaged Package / Contents'));
      expect(DisputeCategory.unreachableRecipient.label,
          equals('Recipient Unreachable (Driver Failure)'));
      expect(DisputeCategory.wrongAddress.label,
          equals('Incorrect or Inaccessible Address'));
    });
  });

  group('DisputeStatus Value Object Tests', () {
    test('fromString parses statuses correctly with fallback', () {
      expect(DisputeStatus.fromString('open'), equals(DisputeStatus.open));
      expect(DisputeStatus.fromString('underInvestigation'),
          equals(DisputeStatus.underInvestigation));
      expect(DisputeStatus.fromString('resolvedRefund'),
          equals(DisputeStatus.resolvedRefund));
      expect(DisputeStatus.fromString('resolvedReturn'),
          equals(DisputeStatus.resolvedReturn));
      expect(DisputeStatus.fromString('rejected'), equals(DisputeStatus.rejected));
      expect(DisputeStatus.fromString(null), equals(DisputeStatus.open));
    });

    test('isPending and isResolved state checks behave as expected', () {
      expect(DisputeStatus.open.isPending, isTrue);
      expect(DisputeStatus.underInvestigation.isPending, isTrue);
      expect(DisputeStatus.resolvedRefund.isPending, isFalse);
      expect(DisputeStatus.resolvedReturn.isPending, isFalse);
      expect(DisputeStatus.rejected.isPending, isFalse);

      expect(DisputeStatus.open.isResolved, isFalse);
      expect(DisputeStatus.resolvedRefund.isResolved, isTrue);
      expect(DisputeStatus.resolvedReturn.isResolved, isTrue);
      expect(DisputeStatus.rejected.isResolved, isTrue);
    });
  });
}
