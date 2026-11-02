part of 'operations_service.dart';

Future<Json> _fileDispute(_CommandContext c) async {
  final orderId = identifier(c.input['orderId']);
  final order = {
    ...existing(await c.tx.get('deliveries/$orderId')),
    'id': orderId,
  };
  final oldPublic = await c.tx.get('publicTracking/${order['trackingNumber']}');
  requireCondition(
    order['customerId'] == c.uid || order['driverId'] == c.uid,
    'You can only report an issue with your own delivery.',
    'permission-denied',
  );
  const categories = {
    'damagedItem',
    'lateDelivery',
    'wrongItem',
    'noShow',
    'riderBehavior',
    'driverMisconduct',
    'fareDispute',
    'missingItem',
    'paymentIssue',
    'unreachableRecipient',
    'wrongAddress',
    'packageRefused',
    'other',
  };
  requireCondition(
    categories.contains(c.input['category']),
    'Choose an issue category.',
  );
  final evidence = c.input['evidenceNotes'] as String?;
  requireCondition(
    evidence == null || evidence.length <= 2000,
    'Evidence notes are too long.',
  );
  final dispute = <String, dynamic>{
    'id': c.eventId,
    'orderId': orderId,
    'trackingNumber': order['trackingNumber'],
    'claimantId': c.uid,
    'claimantName': c.actor['fullName'],
    'claimantPhone': c.actor['phone'],
    'claimantRole': c.role,
    'targetDriverId': order['driverId'],
    'category': c.input['category'],
    'description': requiredText(c.input['description'], 'Description', 2000),
    'evidenceNotes': evidence,
    'status': 'open',
    'createdAt': c.timestamp,
    'assignedAgentId': null,
  };
  c.tx.create('disputes/${c.eventId}', dispute);
  if (c.role == 'driver' &&
      DeliveryPolicy.canTransition(
        order['status'] as String,
        'failedDelivery',
      )) {
    order.addAll({'status': 'failedDelivery', 'failedDeliveryAt': c.timestamp});
    c.publish(order, oldPublic, 'Courier reported a delivery issue');
  }
  return dispute;
}

Future<Json> _manageDispute(_CommandContext c, String command) async {
  c.allowRoles({'admin', 'support'});
  final id = identifier(c.input['disputeId']);
  final dispute = existing(await c.tx.get('disputes/$id'));
  requireCondition(
    {'open', 'underInvestigation'}.contains(dispute['status']),
    'This ticket has already been resolved.',
    'conflict',
  );
  if (command == 'assignDispute') {
    final agentId = c.role == 'support'
        ? c.uid
        : identifier(c.input['agentId'] ?? c.uid);
    final agent = existing(await c.tx.get('users/$agentId'));
    requireCondition(
      {'admin', 'support'}.contains(agent['role']),
      'Choose a support officer.',
    );
    requireCondition(
      c.role == 'admin' ||
          dispute['assignedAgentId'] == null ||
          dispute['assignedAgentId'] == c.uid,
      'Another officer is handling this ticket.',
      'conflict',
    );
    c.tx.update('disputes/$id', {
      'assignedAgentId': agentId,
      'assignedAgentName': agent['fullName'],
      'status': 'underInvestigation',
    });
  } else {
    requireCondition(
      c.role == 'admin' || dispute['assignedAgentId'] == c.uid,
      'Claim the ticket before resolving it.',
      'permission-denied',
    );
    final status = c.input['status'];
    requireCondition(
      {'resolvedRefund', 'resolvedReturn', 'rejected'}.contains(status),
      'Choose a resolution.',
    );
    final orderId = dispute['orderId'] as String;
    final order = {
      ...existing(await c.tx.get('deliveries/$orderId')),
      'id': orderId,
    };
    final customerId = order['customerId'] as String;
    final customer = existing(await c.tx.get('users/$customerId'));
    final oldPublic = await c.tx.get(
      'publicTracking/${order['trackingNumber']}',
    );
    final driver = order['driverId'] == null
        ? null
        : await c.tx.get('users/${order['driverId']}');
    final notes = requiredText(
      c.input['resolutionNotes'],
      'Resolution notes',
      1000,
    );
    final update = <String, dynamic>{
      'status': status,
      'resolutionNotes': notes,
      'resolvedBy': c.uid,
      'resolvedAt': c.timestamp,
    };
    if (status == 'resolvedRefund') {
      c.allowRoles({'admin'});
      requireCondition(
        DeliveryPolicy.terminal.contains(order['status']) ||
            order['status'] == 'failedDelivery',
        'Finish or return the delivery before issuing a refund.',
        'invalid-transition',
      );
      final amount = minorUnits(c.input['refundAmount']);
      final refunded = minorUnits(order['refundedAmount'] ?? 0);
      final price = order['pricing'] as Map;
      requireCondition(
        price['isPaid'] == true &&
            amount > 0 &&
            amount <= minorUnits(price['totalFare']) - refunded,
        'Refund cannot exceed the remaining confirmed payment.',
        'invalid-refund',
      );
      c.tx.update('users/$customerId', {
        'walletBalance':
            (minorUnits(customer['walletBalance'] ?? 0) + amount) / 100,
      });
      c.ledger(
        customerId,
        'refund-$id',
        amount / 100,
        'refund',
        'Delivery dispute refund',
        id,
      );
      c.tx.update('deliveries/$orderId', {
        'refundedAmount': (refunded + amount) / 100,
      });
      update['refundAmount'] = amount / 100;
      if (order['status'] == 'failedDelivery') {
        order.addAll({
          'status': 'returnedToHub',
          'refundedAmount': (refunded + amount) / 100,
        });
        if (driver != null) {
          c.releaseDriver(order['driverId'] as String, driver, [orderId]);
        }
        c.tx.delete('deliveryPins/$orderId');
        c.publish(order, oldPublic, 'Failed delivery closed with refund');
      }
    }
    if (status == 'resolvedReturn') {
      requireCondition(
        DeliveryPolicy.canTransition(
          order['status'] as String,
          'returnedToHub',
          admin: true,
        ),
        'This delivery cannot be returned.',
        'invalid-transition',
      );
      order['status'] = 'returnedToHub';
      if (driver != null) {
        c.releaseDriver(order['driverId'] as String, driver, [orderId]);
      }
      c.tx.delete('deliveryPins/$orderId');
      c.publish(order, oldPublic, notes);
    }
    c.tx.update('disputes/$id', update);
  }
  c.tx.create('disputes/$id/audit/${c.eventId}', {
    'actorId': c.uid,
    'action': command,
    'timestamp': c.timestamp,
  });
  return {};
}
