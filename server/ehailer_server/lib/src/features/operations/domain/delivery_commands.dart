part of 'operations_service.dart';

Future<Json> _createOrder(_CommandContext c, Json prepared) async {
  c.allowRoles({'customer'});
  requireCondition(
    {'express', 'consignment'}.contains(c.input['type']),
    'Choose a delivery type.',
  );
  final id = c.eventId;
  final price = prepared['pricing'] as Json;
  final order = <String, dynamic>{
    ...prepared,
    'id': id,
    'trackingNumber':
        'EH-${List.generate(16, (_) => c.random.nextInt(256).toRadixString(16).padLeft(2, '0')).join().toUpperCase()}',
    'type': c.input['type'],
    'vehicleType': c.input['vehicleType'],
    'status': c.input['type'] == 'express' ? 'searchingDriver' : 'created',
    'customerId': c.uid,
    'customerName': c.actor['fullName'],
    'customerPhone': c.actor['phone'],
    'driverId': null,
    'driverName': null,
    'driverPhone': null,
    'createdAt': c.timestamp,
    'createdBy': c.uid,
    'isSettled': false,
    'refundedAmount': 0.0,
  };
  if (price['paymentMethod'] == 'wallet') {
    final balance = minorUnits(c.actor['walletBalance'] ?? 0);
    final fare = minorUnits(price['totalFare']);
    requireCondition(
      balance >= fare,
      'Your balance is too low. Choose cash on delivery.',
      'insufficient-balance',
    );
    c.tx.update('users/${c.uid}', {'walletBalance': (balance - fare) / 100});
    c.ledger(
      c.uid,
      'charge-$id',
      fare / 100,
      'tripPayment',
      'Delivery payment',
      id,
    );
  }
  c.tx.create('deliveryPins/$id', {
    'customerId': c.uid,
    'pin': c.random.nextInt(10000).toString().padLeft(4, '0'),
    'attempts': 0,
    'lockedUntil': null,
  });
  c.publish(order, null, 'Order created');
  return order;
}

Future<Json> _updateDelivery(_CommandContext c, String command) async {
  final id = identifier(c.input['orderId']);
  final order = {...existing(await c.tx.get('deliveries/$id')), 'id': id};
  final oldPublic = await c.tx.get('publicTracking/${order['trackingNumber']}');
  final pinData = await c.tx.get('deliveryPins/$id');
  final customer = existing(await c.tx.get('users/${order['customerId']}'));
  final driver = order['driverId'] == null
      ? null
      : existing(await c.tx.get('users/${order['driverId']}'));
  final assigned = c.role == 'driver' && order['driverId'] == c.uid;
  final owner = order['customerId'] == c.uid;
  final price = Json.from(order['pricing'] as Map);
  String? note;
  switch (command) {
    case 'acceptJob':
      c.allowRoles({'driver'});
      requireCondition(
        DriverAccessPolicy.eligible(c.actor, order),
        'You need approval for this vehicle and pickup area.',
        'permission-denied',
      );
      requireCondition(
        c.actor['isAvailable'] == true &&
            _CommandContext.activeIds(c.actor).isEmpty,
        'Go online and finish your current delivery first.',
        'conflict',
      );
      requireCondition(
        order['status'] == 'searchingDriver' && order['driverId'] == null,
        'This delivery has already been assigned.',
        'conflict',
      );
      requireCondition(
        order['vehicleType'] == c.actor['vehicleType'],
        'This delivery requires a different vehicle.',
      );
      order.addAll({
        'status': 'assigned',
        'driverId': c.uid,
        'driverName': c.actor['fullName'],
        'driverPhone': c.actor['phone'],
        'assignedAt': c.timestamp,
      });
      c.tx.update('users/${c.uid}', {
        'currentOrderId': id,
        'activeOrderIds': [id],
      });
      note = 'Courier accepted the delivery';
    case 'updateDriverLocation':
      requireCondition(
        assigned && !DeliveryPolicy.terminal.contains(order['status']),
        'Only the active assigned courier can share location.',
        'permission-denied',
      );
      final lat = finiteNumber(c.input['driverLatitude'], -90, 90, 'latitude');
      final lng = finiteNumber(
        c.input['driverLongitude'],
        -180,
        180,
        'longitude',
      );
      c.tx.update('deliveries/$id', {
        'driverLatitude': lat,
        'driverLongitude': lng,
        'locationUpdatedAt': c.timestamp,
      });
      c.tx.update('users/${c.uid}', {
        'lastKnownLatitude': lat,
        'lastKnownLongitude': lng,
        'lastSeenAt': c.timestamp,
      });
    case 'updateStatus':
      requireCondition(
        assigned,
        'Only the assigned courier can update progress.',
        'permission-denied',
      );
      final status = c.input['status'] as String? ?? '';
      requireCondition(
        {
          'arrivedPickup',
          'pickedUp',
          'inTransit',
          'arrivedDropoff',
          'failedDelivery',
        }.contains(status),
        'Use the dedicated handover or cancellation action.',
      );
      requireCondition(
        DeliveryPolicy.canTransition(order['status'] as String, status),
        'This stage is not valid for the current delivery.',
        'invalid-transition',
      );
      order.addAll({'status': status, '${status}At': c.timestamp});
      note = 'Delivery moved to $status';
    case 'completeDelivery':
      requireCondition(
        assigned,
        'Only the assigned courier can confirm handover.',
        'permission-denied',
      );
      if (order['status'] == 'delivered' && order['isSettled'] == true) {
        return {'alreadyCompleted': true};
      }
      requireCondition(
        DeliveryPolicy.canTransition(order['status'] as String, 'delivered'),
        'This delivery is not ready for handover.',
        'invalid-transition',
      );
      requireCondition(
        pinData != null,
        'This delivery needs a verification PIN. Contact support.',
        'pin-unavailable',
      );
      final locked = DateTime.tryParse(
        pinData!['lockedUntil'] as String? ?? '',
      );
      requireCondition(
        locked == null || !locked.isAfter(c.now),
        'Too many incorrect attempts. Try again in 15 minutes.',
        'pin-locked',
      );
      final supplied = c.input['pin'] as String? ?? '';
      final expected = pinData['pin'] as String;
      var difference = supplied.length ^ expected.length;
      for (var i = 0; i < expected.length; i++) {
        difference |=
            expected.codeUnitAt(i) ^
            (i < supplied.length ? supplied.codeUnitAt(i) : 0);
      }
      if (difference != 0) {
        final attempts = locked != null
            ? 1
            : (pinData['attempts'] as num? ?? 0).toInt() + 1;
        c.tx.update('deliveryPins/$id', {
          'attempts': attempts,
          'lockedUntil': attempts >= 5
              ? c.now.add(const Duration(minutes: 15)).toIso8601String()
              : null,
        });
        return {
          'error': {
            'code': 'invalid-pin',
            'message': 'The handover PIN is incorrect.',
          },
        };
      }
      final cod = price['paymentMethod'] == 'cashOnDelivery';
      requireCondition(
        cod || price['isPaid'] == true,
        'Payment has not been confirmed.',
        'payment-required',
      );
      final amount = minorUnits(
        cod ? price['platformCommission'] : price['driverEarnings'],
      );
      final balance = minorUnits(
        c.actor['walletBalance'] ?? 0,
        allowNegative: true,
      );
      c.tx.update('users/${c.uid}', {
        'walletBalance': (balance + (cod ? -amount : amount)) / 100,
        'totalTrips': (c.actor['totalTrips'] as num? ?? 0).toInt() + 1,
      });
      c.releaseDriver(c.uid, c.actor, [id]);
      c.ledger(
        c.uid,
        'settlement-$id',
        amount / 100,
        cod ? 'codCommission' : 'tripPayout',
        cod ? 'Cash delivery commission' : 'Delivery earnings',
        id,
      );
      order.addAll({
        'status': 'delivered',
        'deliveredAt': c.timestamp,
        'settledAt': c.timestamp,
        'isSettled': true,
        'pricing': {...price, 'isPaid': true},
      });
      c.tx.delete('deliveryPins/$id');
      note = 'Recipient PIN verified and delivery settled';
    case 'cancelOrder':
      requireCondition(
        owner || assigned || c.role == 'admin',
        'You cannot cancel this delivery.',
        'permission-denied',
      );
      requireCondition(
        DeliveryPolicy.canTransition(
          order['status'] as String,
          'cancelled',
          admin: c.role == 'admin',
        ),
        'This delivery can no longer be cancelled.',
        'invalid-transition',
      );
      note = requiredText(c.input['reason'], 'Cancellation reason', 500);
      if (price['paymentMethod'] == 'wallet' &&
          price['isPaid'] == true &&
          order['isSettled'] != true) {
        final amount =
            minorUnits(price['totalFare']) -
            minorUnits(order['refundedAmount'] ?? 0);
        c.tx.update('users/${order['customerId']}', {
          'walletBalance':
              (minorUnits(customer['walletBalance'] ?? 0) + amount) / 100,
        });
        c.ledger(
          order['customerId'] as String,
          'cancel-$id',
          amount / 100,
          'refund',
          'Cancelled delivery refund',
          id,
        );
        order['refundedAmount'] = price['totalFare'];
      }
      if (driver != null) {
        c.releaseDriver(order['driverId'] as String, driver, [id]);
      }
      order.addAll({
        'status': 'cancelled',
        'cancelledAt': c.timestamp,
        'cancelledByRole': c.role,
        'cancellationReason': note,
      });
      c.tx.delete('deliveryPins/$id');
    case 'rateDelivery':
      requireCondition(
        owner && order['status'] == 'delivered' && driver != null,
        'Only the customer can rate a completed delivery.',
        'permission-denied',
      );
      requireCondition(
        order['customerRating'] == null,
        'This delivery has already been rated.',
        'conflict',
      );
      final rating = finiteNumber(c.input['rating'], 1, 5, 'rating');
      final count = (driver!['ratingCount'] as num? ?? 0).toInt();
      c.tx.update('users/${order['driverId']}', {
        'rating':
            (((driver['rating'] as num? ?? 5) * count) + rating) / (count + 1),
        'ratingCount': count + 1,
      });
      final review = c.input['review'] as String? ?? '';
      requireCondition(
        review.length <= 1000,
        'Review must be at most 1000 characters.',
      );
      c.tx.update('deliveries/$id', {
        'customerRating': rating,
        'customerReview': review.trim(),
      });
  }
  if (note != null) c.publish(order, oldPublic, note);
  return {};
}

Future<Json> _assignOrders(_CommandContext c) async {
  c.allowRoles({'admin'});
  final rawIds = c.input['orderIds'];
  requireCondition(
    rawIds is List && rawIds.isNotEmpty && rawIds.length <= 20,
    'Select between 1 and 20 deliveries.',
  );
  final ids = (rawIds as List).map(identifier).toSet().toList();
  final target = identifier(c.input['driverId']);
  final driver = existing(await c.tx.get('users/$target'));
  requireCondition(
    driver['role'] == 'driver' &&
        driver['driverApproved'] == true &&
        driver['isAvailable'] == true,
    'Choose an online courier.',
  );
  requireCondition(
    _CommandContext.activeIds(driver).every(ids.contains),
    'This courier already has an active assignment.',
    'conflict',
  );
  final orders = <Json>[];
  final publications = <Json?>[];
  final oldDrivers = <String, Json>{};
  for (final id in ids) {
    final order = {...existing(await c.tx.get('deliveries/$id')), 'id': id};
    requireCondition(
      DeliveryPolicy.canTransition(
        order['status'] as String,
        'assigned',
        admin: true,
      ),
      'Completed or cancelled deliveries cannot be reassigned.',
      'invalid-transition',
    );
    requireCondition(
      DriverAccessPolicy.eligible(driver, order),
      'The driver must be approved for every vehicle and pickup area.',
      'permission-denied',
    );
    orders.add(order);
    publications.add(
      await c.tx.get('publicTracking/${order['trackingNumber']}'),
    );
    if (order['driverId'] case final String oldId when oldId != target) {
      oldDrivers[oldId] = existing(await c.tx.get('users/$oldId'));
    }
  }
  for (final entry in oldDrivers.entries) {
    c.releaseDriver(entry.key, entry.value, ids);
  }
  for (var i = 0; i < orders.length; i++) {
    orders[i].addAll({
      'status': 'assigned',
      'driverId': target,
      'driverName': driver['fullName'],
      'driverPhone': driver['phone'],
      'driverLatitude': null,
      'driverLongitude': null,
      'assignedAt': c.timestamp,
    });
    c.publish(
      orders[i],
      publications[i],
      'Courier assigned by dispatch',
      event: '${c.eventId}-$i',
    );
  }
  c.tx.update('users/$target', {
    'currentOrderId': ids.first,
    'activeOrderIds': ids,
  });
  return {};
}

Future<Json> _setDriverApproval(_CommandContext c) async {
  c.allowRoles({'admin'});
  final target = identifier(c.input['driverId']);
  final driver = existing(await c.tx.get('users/$target'));
  requireCondition(driver['role'] == 'driver', 'Choose a driver account.');
  requireCondition(c.input['approved'] is bool, 'Choose an approval status.');
  final approved = c.input['approved'] == true;
  requireCondition(
    _CommandContext.activeIds(driver).isEmpty,
    'Reassign or finish active deliveries before changing approval.',
    'conflict',
  );
  final areas = <String>[];
  String? label;
  if (approved) {
    requiredText(driver['vehiclePlateNumber'], 'Driver plate number', 20);
    requiredText(driver['vehicleModel'], 'Driver vehicle model', 50);
    requireCondition(
      {'bike', 'car', 'van', 'truck'}.contains(driver['vehicleType']),
      'The driver must first select a vehicle.',
    );
    final lat = finiteNumber(
      c.input['latitude'],
      -89.8,
      89.8,
      'service area latitude',
    );
    final lng = finiteNumber(
      c.input['longitude'],
      -179.8,
      179.8,
      'service area longitude',
    );
    label = requiredText(c.input['areaName'], 'Operating area', 120);
    areas.addAll(DriverAccessPolicy.areas(lat, lng));
  }
  c.tx.update('users/$target', {
    'driverApproved': approved,
    'serviceAreaIds': areas,
    'serviceAreaName': label,
    'isAvailable': false,
    'approvalUpdatedAt': c.timestamp,
    'approvalUpdatedBy': c.uid,
  });
  c.tx.create('driverApprovalAudit/${c.eventId}', {
    'driverId': target,
    'approved': approved,
    'serviceAreaIds': areas,
    'actorId': c.uid,
    'createdAt': c.timestamp,
  });
  return {};
}
