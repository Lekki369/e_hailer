import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import '../../../core/domain/command_store.dart';
import '../../../core/domain/operation_failure.dart';
import '../../delivery/domain/delivery_policy.dart';
import '../../map/domain/road_route.dart';

part 'delivery_commands.dart';
part 'wallet_commands.dart';
part 'support_commands.dart';

/// Business writes are authorized and committed together. A replay key is scoped
/// to the Firebase UID and operation; payload changes cannot reuse that key.
class OperationsService {
  final CommandStore store;
  final RouteLookup routeLookup;
  final DateTime Function() clock;
  final Random _random = Random.secure();
  OperationsService({
    required this.store,
    required this.routeLookup,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;

  Future<Json> execute(
    String command,
    String uid,
    Json input,
    String requestId,
  ) async {
    identifier(uid);
    requireCondition(
      RegExp(r'^[A-Za-z0-9_-]{16,128}$').hasMatch(requestId),
      'A valid request key is required.',
    );
    if (command == 'topUpWallet') {
      throw const OperationFailure(
        'payment-unavailable',
        'Wallet top-ups are not available yet. No payment has been taken.',
      );
    }
    final eventId = _hash({'uid': uid, 'command': command, 'key': requestId});
    final requestHash = _hash({'command': command, 'input': input});
    final receiptPath = 'commandReceipts/$eventId';
    Json? prepared;
    if (command == 'quoteOrder') {
      // Check committed retries before making another route request.
      final previous = await store.transaction((tx) => tx.get(receiptPath));
      if (previous != null) {
        requireCondition(
          previous['requestHash'] == requestHash,
          'This request key has already been used.',
          'conflict',
        );
        return Json.from(previous['result'] as Map);
      }
      final actor = existing(
        await store.transaction((tx) => tx.get('users/$uid')),
      );
      requireCondition(
        actor['role'] == 'customer',
        'Only customers can request a delivery quote.',
        'permission-denied',
      );
      final pickup = DeliveryPolicy.location(input['pickupLocation']);
      final dropoff = DeliveryPolicy.location(input['dropoffLocation']);
      requireCondition(
        pickup['latitude'] != dropoff['latitude'] ||
            pickup['longitude'] != dropoff['longitude'],
        'Pickup and drop-off must differ.',
      );
      final parcel = DeliveryPolicy.parcel(input['parcel']);
      final road = await routeLookup(pickup, dropoff);
      prepared = {
        'pickupLocation': pickup,
        'dropoffLocation': dropoff,
        'parcel': parcel,
        'distanceKm': road.distanceKm,
        'estimatedDurationMinutes': road.durationMinutes,
        'pricing': DeliveryPolicy.pricing(
          road.distanceKm,
          parcel,
          input['vehicleType'] as String? ?? '',
          input['paymentMethod'] as String? ?? 'cashOnDelivery',
        ),
      };
    }
    final now = clock().toUtc();
    final result = await store.transaction((tx) async {
      final actor = {...existing(await tx.get('users/$uid')), 'uid': uid};
      final receipt = await tx.get(receiptPath);
      if (receipt != null) {
        requireCondition(
          receipt['requestHash'] == requestHash,
          'This request key has already been used.',
          'conflict',
        );
        return Json.from(receipt['result'] as Map);
      }
      final context = _CommandContext(tx, actor, input, eventId, now, _random);
      final Json output;
      switch (command) {
        case 'quoteOrder':
          context.allowRoles({'customer'});
          final expires = now
              .add(const Duration(minutes: 10))
              .toIso8601String();
          tx.create('deliveryQuotes/$eventId', {
            'uid': uid,
            'inputHash': _hash(_bookingInput(input)),
            'prepared': prepared,
            'expiresAt': expires,
            'usedOrderId': null,
          });
          output = {'id': eventId, ...prepared!, 'expiresAt': expires};
        case 'createOrder':
          final quoteId = identifier(input['quoteId']);
          final quote = existing(await tx.get('deliveryQuotes/$quoteId'));
          requireCondition(
            quote['uid'] == uid,
            'This quote belongs to another customer.',
            'permission-denied',
          );
          requireCondition(
            quote['inputHash'] == _hash(_bookingInput(input)),
            'Your delivery details changed. Get a new quote.',
            'quote-changed',
          );
          requireCondition(
            DateTime.parse(quote['expiresAt'] as String).isAfter(now),
            'This quote expired. Get a new quote.',
            'quote-expired',
          );
          requireCondition(
            quote['usedOrderId'] == null,
            'This quote has already been booked.',
            'conflict',
          );
          output = await _createOrder(
            context,
            Json.from(quote['prepared'] as Map),
          );
          tx.update('deliveryQuotes/$quoteId', {'usedOrderId': output['id']});
        case 'acceptJob':
        case 'updateStatus':
        case 'completeDelivery':
        case 'cancelOrder':
        case 'updateDriverLocation':
        case 'rateDelivery':
          output = await _updateDelivery(context, command);
        case 'assignOrders':
          output = await _assignOrders(context);
        case 'submitPayout':
          output = await _submitPayout(context);
        case 'approvePayout':
        case 'rejectPayout':
          output = await _processPayout(context, command);
        case 'fileDispute':
          output = await _fileDispute(context);
        case 'assignDispute':
        case 'resolveDispute':
          output = await _manageDispute(context, command);
        default:
          throw const OperationFailure('not-found', 'Unknown operation.');
      }
      tx.create(receiptPath, {
        'uid': uid,
        'command': command,
        'requestHash': requestHash,
        'result': output,
        'createdAt': context.timestamp,
      });
      return output;
    });
    if (result['error'] case final Map error) {
      throw OperationFailure(
        error['code'] as String,
        error['message'] as String,
      );
    }
    return result;
  }

  static Json _bookingInput(Json input) => {
    for (final key in [
      'type',
      'vehicleType',
      'pickupLocation',
      'dropoffLocation',
      'parcel',
      'paymentMethod',
    ])
      key: input[key],
  };

  static dynamic _canonical(dynamic value) {
    if (value is Map) {
      final keys = value.keys.cast<String>().toList()..sort();
      return {for (final key in keys) key: _canonical(value[key])};
    }
    if (value is List) return value.map(_canonical).toList();
    return value;
  }

  static String _hash(Json value) =>
      sha256.convert(utf8.encode(jsonEncode(_canonical(value)))).toString();
}

class _CommandContext {
  final CommandTransaction tx;
  final Json actor;
  final Json input;
  final String eventId;
  final DateTime now;
  final Random random;
  _CommandContext(
    this.tx,
    this.actor,
    this.input,
    this.eventId,
    this.now,
    this.random,
  );
  String get uid => actor['uid'] as String;
  String get role => actor['role'] as String;
  String get timestamp => now.toIso8601String();
  void allowRoles(Set<String> roles) => requireCondition(
    roles.contains(role),
    'You do not have permission for this action.',
    'permission-denied',
  );
  static List<String> activeIds(Json driver) => {
    ...((driver['activeOrderIds'] as List?) ?? []).whereType<String>(),
    if (driver['currentOrderId'] case final String id) id,
  }.toList();
  void releaseDriver(
    String driverId,
    Json driver,
    Iterable<String> completedIds,
  ) {
    final remaining = activeIds(driver)..removeWhere(completedIds.contains);
    tx.update('users/$driverId', {
      'activeOrderIds': remaining,
      'currentOrderId': remaining.firstOrNull,
    });
  }

  void ledger(
    String userId,
    String id,
    double amount,
    String type,
    String title,
    String reference,
  ) {
    tx.create('users/$userId/transactions/$id', {
      'userId': userId,
      'amount': amount,
      'type': type,
      'title': title,
      'referenceId': reference,
      'createdAt': timestamp,
    });
  }

  void publish(Json order, Json? oldPublic, String note, {String? event}) {
    order['updatedAt'] = timestamp;
    order['updatedBy'] = uid;
    final id = order['id'] as String;
    tx.set('deliveries/$id', order);
    tx.create('deliveries/$id/timeline/${event ?? eventId}', {
      'orderId': id,
      'status': order['status'],
      'actorId': uid,
      'actorRole': role,
      'timestamp': timestamp,
      'note': note,
    });
    tx.set('publicTracking/${order['trackingNumber']}', {
      ...DeliveryPolicy.publicTracking(order, oldPublic),
      'expiresAtMillis': now
          .add(const Duration(days: 30))
          .millisecondsSinceEpoch,
    });
    if (order['status'] == 'searchingDriver' && order['driverId'] == null) {
      tx.set('jobOffers/$id', {
        for (final key in [
          'id',
          'trackingNumber',
          'type',
          'status',
          'vehicleType',
          'createdAt',
          'parcel',
          'pricing',
          'distanceKm',
          'estimatedDurationMinutes',
        ])
          key: order[key],
        'customerId': '',
        'customerName': '',
        'customerPhone': '',
        'pickupLocation': {
          ...order['pickupLocation'] as Map,
          'contactName': '',
          'contactPhone': '',
        },
        'dropoffLocation': {
          ...order['dropoffLocation'] as Map,
          'contactName': '',
          'contactPhone': '',
        },
      });
    } else {
      tx.delete('jobOffers/$id');
    }
  }
}
