import 'dart:async';
import 'package:e_hailer/core/domain/failures/app_failure.dart';
import 'package:e_hailer/core/presentation/utils/fp_framework.dart';
import 'package:e_hailer/features/auth/domain/user_entity.dart';
import 'package:e_hailer/features/auth/presentation/providers/auth_providers.dart';
import 'package:e_hailer/features/delivery/domain/entities/delivery_order.dart';
import 'package:e_hailer/features/delivery/domain/value_objects/delivery_type.dart';
import 'package:e_hailer/features/delivery/infrastructure/delivery_remote_service.dart';
import 'package:e_hailer/features/delivery/presentation/providers/delivery_providers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class OfferService implements DeliveryRemoteService {
  final queries = <(String, List<String>)>[];
  bool cancelled = false;
  @override
  Stream<Either<AppFailure, List<DeliveryOrder>>> watchAvailableOrders(
    String vehicleType,
    List<String> serviceAreaIds,
  ) {
    queries.add((vehicleType, serviceAreaIds));
    final stream = StreamController<Either<AppFailure, List<DeliveryOrder>>>(
      onCancel: () => cancelled = true,
    );
    stream.add(right(<DeliveryOrder>[]));
    return stream.stream;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final approved = UserEntity(
    uid: 'driver',
    role: UserRole.driver,
    fullName: 'Test Driver',
    email: 'driver@example.test',
    phone: '08000000000',
    createdAt: DateTime(2026),
    driverApproved: true,
    isAvailable: true,
    vehicleType: VehicleType.bike,
    serviceAreaIds: const ['65:33'],
  );

  test(
    'pending, offline and unscoped profiles never open an offers subscription',
    () async {
      for (final driver in [
        null,
        approved.copyWith(driverApproved: false),
        approved.copyWith(isAvailable: false),
        approved.copyWith(serviceAreaIds: []),
      ]) {
        final container = ProviderContainer(
          overrides: [
            currentUserProfileProvider.overrideWith(
              (ref) => Stream.value(driver),
            ),
            deliveryRemoteServiceProvider.overrideWith(
              (ref) => throw StateError('Must not query offers'),
            ),
          ],
        );
        final profileSubscription = container.listen(
          currentUserProfileProvider,
          (_, _) {},
        );
        final offersSubscription = container.listen(
          availableOrdersStreamProvider,
          (_, _) {},
        );
        await container.read(currentUserProfileProvider.future);
        expect(
          await container.read(availableOrdersStreamProvider.future),
          isEmpty,
        );
        offersSubscription.close();
        profileSubscription.close();
        container.dispose();
      }
    },
  );

  test(
    'approval scopes the query and revocation closes the old subscription',
    () async {
      final profiles = StreamController<UserEntity?>();
      final service = OfferService();
      final container = ProviderContainer(
        overrides: [
          currentUserProfileProvider.overrideWith((ref) => profiles.stream),
          deliveryRemoteServiceProvider.overrideWithValue(service),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await profiles.close();
      });
      final subscription = container.listen(
        availableOrdersStreamProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      profiles.add(approved);
      await container.read(currentUserProfileProvider.future);
      await container.read(availableOrdersStreamProvider.future);
      expect(service.queries, hasLength(1));
      expect(service.queries.single.$1, 'bike');
      expect(service.queries.single.$2, ['65:33']);
      profiles.add(
        approved.copyWith(driverApproved: false, serviceAreaIds: []),
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        await container.read(availableOrdersStreamProvider.future),
        isEmpty,
      );
      expect(service.cancelled, true);
      expect(service.queries.length, 1);
    },
  );
}
