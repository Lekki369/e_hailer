import 'dart:io';
import 'package:firebase_admin_sdk/firebase_admin_sdk.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:ehailer_server/src/core/domain/command_store.dart';
import 'package:ehailer_server/src/core/domain/operation_failure.dart';
import 'package:ehailer_server/src/core/infrastructure/firestore_command_store.dart';
import 'package:ehailer_server/src/features/delivery/domain/delivery_policy.dart';
import 'package:ehailer_server/src/features/map/domain/road_route.dart';
import 'package:ehailer_server/src/features/operations/domain/operations_service.dart';
import 'support/memory_command_store.dart';

void main() {
  final emulator = Platform.environment['FIRESTORE_EMULATOR_HOST'];
  late CommandStore store;
  late OperationsService service;
  var serial = 0;
  String key() => 'request-${(++serial).toString().padLeft(16, '0')}';
  Future<Json?> read(String path) => store.transaction((tx) => tx.get(path));
  Future<void> put(String path, Json value) =>
      store.transaction((tx) async => tx.set(path, value));
  Future<Json> run(
    String command,
    String actor,
    Json input, {
    String? requestId,
  }) async {
    final request = requestId ?? key();
    if (command == 'createOrder' && !input.containsKey('quoteId')) {
      final quote = await service.execute(
        'quoteOrder',
        actor,
        input,
        'quote-$request',
      );
      input = {...input, 'quoteId': quote['id']};
    }
    return service.execute(command, actor, input, request);
  }

  Json user(String uid, String role, [double balance = 0]) => {
    'uid': uid,
    'role': role,
    'fullName': uid,
    'phone': '08000000000',
    'walletBalance': balance,
    'isAvailable': true,
    'vehicleType': 'bike',
  };
  Json booking({String method = 'wallet'}) => {
    'type': 'express',
    'vehicleType': 'bike',
    'paymentMethod': method,
    'pickupLocation': {
      'latitude': 6.52,
      'longitude': 3.37,
      'address': 'Pickup',
      'contactName': 'Sender',
      'contactPhone': '08000000001',
    },
    'dropoffLocation': {
      'latitude': 6.55,
      'longitude': 3.4,
      'address': 'Destination',
      'contactName': 'Recipient',
      'contactPhone': '08000000002',
    },
    'parcel': {'category': 'parcel', 'weightKg': 2.0},
  };
  Future<Json> create({String method = 'wallet'}) =>
      run('createOrder', 'customer', booking(method: method));
  Future<void> ready(Json order) async {
    final id = order['id'];
    await run('acceptJob', 'driver', {'orderId': id});
    for (final status in ['arrivedPickup', 'inTransit']) {
      await run('updateStatus', 'driver', {'orderId': id, 'status': status});
    }
  }

  Matcher failure(String code) =>
      isA<OperationFailure>().having((e) => e.code, 'code', code);

  setUp(() async {
    if (emulator != null) {
      if (!emulator.startsWith('127.0.0.1:') &&
          !emulator.startsWith('localhost:')) {
        throw StateError('Tests require a local emulator.');
      }
      final response = await http.delete(
        Uri.parse(
          'http://$emulator/emulator/v1/projects/demo-ehailer/databases/(default)/documents',
        ),
      );
      expect(response.statusCode, 200);
      final app = FirebaseApp.initializeApp(
        name: 'test-${key()}',
        options: AppOptions(projectId: 'demo-ehailer'),
      );
      store = FirestoreCommandStore(app.firestore());
      addTearDown(() => FirebaseApp.deleteApp(app));
    } else {
      store = MemoryCommandStore();
    }
    service = OperationsService(
      store: store,
      routeLookup: (_, _) async => const RoadRoute(10, 25),
    );
    await put('users/customer', user('customer', 'customer', 10000));
    await put('users/other', user('other', 'customer', 10000));
    await put('users/driver', user('driver', 'driver', 5000));
    await put('users/driver2', user('driver2', 'driver', 5000));
    await put('users/admin', user('admin', 'admin'));
    await put('users/support', user('support', 'support'));
  });

  test('server prices the route and replay debits only once', () async {
    final request = key();
    final input = {
      ...booking(),
      'pricing': {'totalFare': 1},
      'customerId': 'other',
    };
    final order = await run(
      'createOrder',
      'customer',
      input,
      requestId: request,
    );
    expect(order['pricing']['totalFare'], 1700);
    expect(order['customerId'], 'customer');
    expect((await read('users/customer'))!['walletBalance'], 8300);
    expect(
      await run('createOrder', 'customer', input, requestId: request),
      order,
    );
    expect((await read('users/customer'))!['walletBalance'], 8300);
    await expectLater(
      run(
        'createOrder',
        'customer',
        booking(method: 'cashOnDelivery'),
        requestId: request,
      ),
      throwsA(failure('conflict')),
    );
  });
  test(
    'public projection excludes identity, coordinates, prices and PIN',
    () async {
      final order = await create();
      final public = (await read('publicTracking/${order['trackingNumber']}'))!;
      expect(
        public.keys,
        unorderedEquals([
          'trackingNumber',
          'status',
          'type',
          'vehicleType',
          'estimatedDurationMinutes',
          'createdAt',
          'updatedAt',
          'timeline',
          'expiresAtMillis',
        ]),
      );
      expect(order.containsKey('recipientSecurityOtp'), isFalse);
      expect(
        (await read('deliveryPins/${order['id']}'))!['pin'],
        matches(r'^\d{4}$'),
      );
    },
  );
  test('forged roles and unverified top-ups are denied', () async {
    await expectLater(
      run('submitPayout', 'customer', {'role': 'driver', 'amount': 10}),
      throwsA(failure('permission-denied')),
    );
    await expectLater(
      run('topUpWallet', 'customer', {'amount': 5000}),
      throwsA(failure('payment-unavailable')),
    );
    expect((await read('users/customer'))!['walletBalance'], 10000);
  });
  test('two couriers cannot accept the same delivery', () async {
    final order = await create();
    final results = await Future.wait(
      ['driver', 'driver2'].map((uid) async {
        try {
          await run('acceptJob', uid, {'orderId': order['id']});
          return true;
        } on OperationFailure {
          return false;
        }
      }),
    );
    expect(results.where((ok) => ok).length, 1);
  });
  test('ownership and stage checks prevent forged completion', () async {
    final order = await create();
    await expectLater(
      run('completeDelivery', 'other', {'orderId': order['id'], 'pin': '0000'}),
      throwsA(failure('permission-denied')),
    );
    await run('acceptJob', 'driver', {'orderId': order['id']});
    await expectLater(
      run('completeDelivery', 'driver', {
        'orderId': order['id'],
        'pin': '0000',
      }),
      throwsA(failure('invalid-transition')),
    );
    await expectLater(
      run('updateStatus', 'driver', {
        'orderId': order['id'],
        'status': 'delivered',
      }),
      throwsA(failure('invalid-argument')),
    );
  });
  test(
    'incorrect PIN attempts commit, replay does not count twice, lock expires',
    () async {
      final order = await create();
      await ready(order);
      final id = order['id'];
      final secret = (await read('deliveryPins/$id'))!['pin'];
      final wrong = secret == '0000' ? '1111' : '0000';
      final request = key();
      for (var i = 0; i < 2; i++) {
        await expectLater(
          run('completeDelivery', 'driver', {
            'orderId': id,
            'pin': wrong,
          }, requestId: request),
          throwsA(failure('invalid-pin')),
        );
      }
      expect((await read('deliveryPins/$id'))!['attempts'], 1);
      for (var i = 0; i < 4; i++) {
        await expectLater(
          run('completeDelivery', 'driver', {'orderId': id, 'pin': wrong}),
          throwsA(failure('invalid-pin')),
        );
      }
      await expectLater(
        run('completeDelivery', 'driver', {'orderId': id, 'pin': secret}),
        throwsA(failure('pin-locked')),
      );
      service = OperationsService(
        store: store,
        routeLookup: (_, _) async => const RoadRoute(10, 25),
        clock: () => DateTime.now().add(const Duration(minutes: 16)),
      );
      await run('completeDelivery', 'driver', {'orderId': id, 'pin': secret});
      expect(await read('deliveryPins/$id'), isNull);
    },
  );
  test(
    'concurrent completion credits once and terminal states cannot reopen',
    () async {
      final order = await create();
      await ready(order);
      final id = order['id'];
      final secret = (await read('deliveryPins/$id'))!['pin'];
      await Future.wait(
        List.generate(
          3,
          (_) =>
              run('completeDelivery', 'driver', {'orderId': id, 'pin': secret}),
        ),
      );
      expect((await read('users/driver'))!['walletBalance'], 6360);
      expect((await read('users/driver'))!['totalTrips'], 1);
      expect((await read('users/driver'))!['currentOrderId'], isNull);
      await expectLater(
        run('assignOrders', 'admin', {
          'orderIds': [id],
          'driverId': 'driver2',
        }),
        throwsA(failure('invalid-transition')),
      );
      await expectLater(
        run('cancelOrder', 'admin', {'orderId': id, 'reason': 'Retry'}),
        throwsA(failure('invalid-transition')),
      );
    },
  );
  test(
    'cash completion records commission without a fabricated wallet credit',
    () async {
      final order = await create(method: 'cashOnDelivery');
      await ready(order);
      final id = order['id'];
      await run('completeDelivery', 'driver', {
        'orderId': id,
        'pin': (await read('deliveryPins/$id'))!['pin'],
      });
      expect((await read('users/customer'))!['walletBalance'], 10000);
      expect((await read('users/driver'))!['walletBalance'], 4660);
    },
  );
  test('batch completion preserves the next active assignment', () async {
    final a = await create();
    final b = await create();
    await run('assignOrders', 'admin', {
      'orderIds': [a['id'], b['id']],
      'driverId': 'driver',
    });
    await run('cancelOrder', 'customer', {
      'orderId': a['id'],
      'reason': 'No longer needed',
    });
    final driver = (await read('users/driver'))!;
    expect(driver['currentOrderId'], b['id']);
    expect(driver['activeOrderIds'], [b['id']]);
    await expectLater(
      run('acceptJob', 'driver', {'orderId': (await create())['id']}),
      throwsA(failure('conflict')),
    );
  });
  test(
    'concurrent payout requests cannot overdraw and rejection refunds once',
    () async {
      final input = {
        'amount': 4000,
        'bankName': 'Test Bank',
        'accountName': 'Driver',
        'accountNumber': '1234567890',
      };
      final results = await Future.wait(
        List.generate(2, (_) async {
          try {
            return await run('submitPayout', 'driver', input);
          } on OperationFailure {
            return null;
          }
        }),
      );
      expect(results.whereType<Json>().length, 1);
      expect((await read('users/driver'))!['walletBalance'], 1000);
      final id = results.whereType<Json>().single['id'];
      await Future.wait(
        List.generate(
          2,
          (_) => run('rejectPayout', 'admin', {
            'payoutId': id,
            'reason': 'Bank details invalid',
          }),
        ),
      );
      expect((await read('users/driver'))!['walletBalance'], 5000);
      await expectLater(
        run('approvePayout', 'admin', {
          'payoutId': id,
          'transactionRef': 'bank-ref',
        }),
        throwsA(failure('conflict')),
      );
    },
  );
  test('cancellation restores exactly the collected fare once', () async {
    final order = await create();
    await run('cancelOrder', 'customer', {
      'orderId': order['id'],
      'reason': 'Changed plans',
    });
    await expectLater(
      run('cancelOrder', 'customer', {
        'orderId': order['id'],
        'reason': 'Changed plans',
      }),
      throwsA(failure('invalid-transition')),
    );
    expect((await read('users/customer'))!['walletBalance'], 10000);
  });
  test(
    'support cannot issue money; refunds are limited across tickets',
    () async {
      final order = await create();
      await ready(order);
      final id = order['id'];
      await run('completeDelivery', 'driver', {
        'orderId': id,
        'pin': (await read('deliveryPins/$id'))!['pin'],
      });
      Future<Json> ticket() => run('fileDispute', 'customer', {
        'orderId': id,
        'category': 'damagedItem',
        'description': 'Parcel damaged',
      });
      final a = await ticket();
      final b = await ticket();
      await run('assignDispute', 'support', {'disputeId': a['id']});
      final resolve = {
        'disputeId': a['id'],
        'status': 'resolvedRefund',
        'resolutionNotes': 'Damage confirmed',
        'refundAmount': 1000,
      };
      await expectLater(
        run('resolveDispute', 'support', resolve),
        throwsA(failure('permission-denied')),
      );
      await run('resolveDispute', 'admin', resolve);
      await expectLater(
        run('resolveDispute', 'admin', {...resolve, 'disputeId': b['id']}),
        throwsA(failure('invalid-refund')),
      );
      expect((await read('users/customer'))!['walletBalance'], 9300);
    },
  );
  test(
    'quotes bind identity and input, expire, and can be booked only once',
    () async {
      final input = booking();
      final quote = await service.execute(
        'quoteOrder',
        'customer',
        input,
        key(),
      );
      final request = {...input, 'quoteId': quote['id']};
      await expectLater(
        service.execute('createOrder', 'other', request, key()),
        throwsA(failure('permission-denied')),
      );
      await expectLater(
        service.execute('createOrder', 'customer', {
          ...request,
          'vehicleType': 'truck',
        }, key()),
        throwsA(failure('quote-changed')),
      );
      await service.execute('createOrder', 'customer', request, key());
      await expectLater(
        service.execute('createOrder', 'customer', request, key()),
        throwsA(failure('conflict')),
      );
      final next = await service.execute(
        'quoteOrder',
        'customer',
        input,
        key(),
      );
      service = OperationsService(
        store: store,
        routeLookup: (_, _) async => const RoadRoute(10, 25),
        clock: () => DateTime.now().add(const Duration(minutes: 11)),
      );
      await expectLater(
        service.execute('createOrder', 'customer', {
          ...input,
          'quoteId': next['id'],
        }, key()),
        throwsA(failure('quote-expired')),
      );
      expect((await read('users/customer'))!['walletBalance'], 8300);
    },
  );
  test(
    'billable volumetric weight includes all pieces and splits reconcile to rounded total',
    () {
      final parcel = DeliveryPolicy.parcel({
        'category': 'parcel',
        'weightKg': 2,
        'quantity': 3,
        'lengthCm': 50,
        'widthCm': 40,
        'heightCm': 25,
      });
      final price = DeliveryPolicy.pricing(1.23, parcel, 'van', 'wallet');
      expect(price['weightSurcharge'], 2240);
      expect(
        (price['driverEarnings'] as num) + (price['platformCommission'] as num),
        price['totalFare'],
      );
    },
  );

  test('terminal policy rejects every administrative reopening', () {
    for (final status in DeliveryPolicy.terminal) {
      for (final next in [
        'assigned',
        'searchingDriver',
        'cancelled',
        'returnedToHub',
        'delivered',
      ]) {
        expect(
          DeliveryPolicy.canTransition(status, next, admin: true),
          isFalse,
        );
      }
    }
  });
}
