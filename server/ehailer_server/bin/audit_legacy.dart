import 'dart:convert';
import 'dart:io';
import 'package:firebase_admin_sdk/firebase_admin_sdk.dart';

/// Read-only migration inventory. Never prints PINs, user identifiers or balances.
Future<void> main() async {
  final project = Platform.environment['FIREBASE_PROJECT_ID'];
  if (project == null || project.isEmpty) {
    throw StateError('Set FIREBASE_PROJECT_ID.');
  }
  if (Platform.environment.containsKey('FIRESTORE_EMULATOR_HOST') &&
      !project.startsWith('demo-')) {
    throw StateError('Use a demo- project with emulators.');
  }
  final app = FirebaseApp.initializeApp(
    options: AppOptions(projectId: project),
  );
  try {
    final orders = await app.firestore().collection('deliveries').get();
    var exposedPins = 0, unsettledDelivered = 0, legacyTracking = 0;
    for (final doc in orders.docs) {
      final data = doc.data();
      if (data.containsKey('recipientSecurityOtp')) exposedPins++;
      if (data['status'] == 'delivered' && data['isSettled'] != true) {
        unsettledDelivered++;
      }
      if (!RegExp(
        r'^EH-[A-F0-9]{32}$',
      ).hasMatch(data['trackingNumber']?.toString() ?? '')) {
        legacyTracking++;
      }
    }
    stdout.writeln(
      jsonEncode({
        'orders': orders.docs.length,
        'ordersContainingLegacyPinField': exposedPins,
        'deliveredWithoutSettlementMarker': unsettledDelivered,
        'legacyTrackingIdentifiers': legacyTracking,
        'action':
            'Review backups, migrate private PINs, rotate public tokens and reconcile ledger before enabling the new API. No writes were performed.',
      }),
    );
  } finally {
    await FirebaseApp.deleteApp(app);
  }
}
