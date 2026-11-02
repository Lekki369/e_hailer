import 'package:e_hailer/features/wallet/domain/entities/payout_request.dart';
import 'package:e_hailer/features/wallet/domain/value_objects/payout_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PayoutRequest Entity & Serialization Tests', () {
    test('toMap and fromMap serialize and deserialize cleanly', () {
      final request = PayoutRequest(
        id: 'payout-101',
        driverId: 'drv-456',
        driverName: 'Samuel Okoro',
        driverPhone: '+2348033445566',
        amount: 15000.0,
        bankName: 'Guaranty Trust Bank',
        accountNumber: '0123456789',
        accountName: 'Samuel Okoro',
        status: PayoutStatus.pending,
        createdAt: DateTime(2026, 10, 26, 10, 30, 0),
        processedAt: null,
        processedBy: null,
        rejectionReason: null,
        transactionRef: null,
      );

      final map = request.toMap();
      final replica = PayoutRequest.fromMap(map, request.id);

      expect(replica.id, equals(request.id));
      expect(replica.driverId, equals(request.driverId));
      expect(replica.driverName, equals(request.driverName));
      expect(replica.driverPhone, equals(request.driverPhone));
      expect(replica.amount, equals(15000.0));
      expect(replica.bankName, equals('Guaranty Trust Bank'));
      expect(replica.accountNumber, equals('0123456789'));
      expect(replica.accountName, equals('Samuel Okoro'));
      expect(replica.status, equals(PayoutStatus.pending));
      expect(replica.createdAt, equals(request.createdAt));
      expect(replica.processedAt, isNull);
      expect(replica.processedBy, isNull);
      expect(replica.rejectionReason, isNull);
      expect(replica.transactionRef, isNull);
    });

    test('fromMap parses settled and processed payouts with reference', () {
      final processedDate = DateTime(2026, 10, 26, 14, 0, 0);
      final map = {
        'driverId': 'drv-789',
        'driverName': 'Funke Johnson',
        'driverPhone': '+2348077889900',
        'amount': 25000,
        'bankName': 'Access Bank',
        'accountNumber': '0987654321',
        'accountName': 'Funke Johnson',
        'status': 'settled',
        'createdAt': '2026-10-26T11:00:00.000',
        'processedAt': processedDate.toIso8601String(),
        'processedBy': 'admin-adm01',
        'rejectionReason': null,
        'transactionRef': 'NIP-20261026-9921',
      };

      final payout = PayoutRequest.fromMap(map, 'payout-202');

      expect(payout.id, equals('payout-202'));
      expect(payout.driverId, equals('drv-789'));
      expect(payout.driverName, equals('Funke Johnson'));
      expect(payout.amount, equals(25000.0));
      expect(payout.status, equals(PayoutStatus.settled));
      expect(payout.processedAt, equals(processedDate));
      expect(payout.processedBy, equals('admin-adm01'));
      expect(payout.transactionRef, equals('NIP-20261026-9921'));
    });

    test('copyWith modifies state immutably', () {
      final initial = PayoutRequest(
        id: 'payout-303',
        driverId: 'drv-111',
        driverName: 'Driver X',
        driverPhone: '+2348000000000',
        amount: 8000.0,
        bankName: 'Zenith Bank',
        accountNumber: '2223334445',
        accountName: 'Driver X',
        status: PayoutStatus.pending,
        createdAt: DateTime(2026, 10, 26, 8, 0, 0),
      );

      final settledTime = DateTime(2026, 10, 26, 9, 30, 0);
      final updated = initial.copyWith(
        status: PayoutStatus.settled,
        processedAt: settledTime,
        processedBy: 'ops_agent_1',
        transactionRef: 'TRX_882910',
      );

      expect(updated.status, equals(PayoutStatus.settled));
      expect(updated.processedAt, equals(settledTime));
      expect(updated.processedBy, equals('ops_agent_1'));
      expect(updated.transactionRef, equals('TRX_882910'));
      expect(updated.amount, equals(8000.0));
      expect(initial.status, equals(PayoutStatus.pending));
    });

    test('Equatable value equality functions correctly', () {
      final date = DateTime(2026, 10, 26, 12, 0, 0);
      final r1 = PayoutRequest(
        id: 'req-1',
        driverId: 'drv-1',
        driverName: 'Name',
        driverPhone: '123',
        amount: 5000,
        bankName: 'Bank',
        accountNumber: '1234567890',
        accountName: 'Account',
        status: PayoutStatus.pending,
        createdAt: date,
      );

      final r2 = PayoutRequest(
        id: 'req-1',
        driverId: 'drv-1',
        driverName: 'Name',
        driverPhone: '123',
        amount: 5000,
        bankName: 'Bank',
        accountNumber: '1234567890',
        accountName: 'Account',
        status: PayoutStatus.pending,
        createdAt: date,
      );

      expect(r1, equals(r2));
      expect(r1.hashCode, equals(r2.hashCode));
    });
  });
}
