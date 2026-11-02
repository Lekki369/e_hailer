import 'dart:async';

import 'package:e_hailer/core/domain/failures/app_failure.dart';
import 'package:e_hailer/core/presentation/utils/fp_framework.dart';
import 'package:e_hailer/features/auth/domain/user_entity.dart';
import 'package:e_hailer/features/auth/infrastructure/auth_remote_service.dart';
import 'package:e_hailer/features/auth/presentation/providers/auth_providers.dart';
import 'package:e_hailer/features/auth/presentation/screens/profile_screen.dart';
import 'package:e_hailer/features/delivery/domain/value_objects/delivery_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class PendingProfileService implements AuthRemoteService {
  final result = Completer<Either<AppFailure, Unit>>();
  bool called = false;

  @override
  Future<Either<AppFailure, Unit>> updateUserProfile({
    required String uid,
    String? fullName,
    String? phone,
    VehicleType? vehicleType,
    String? vehiclePlateNumber,
    String? vehicleModel,
  }) {
    called = true;
    return result.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  for (final action in ['Save Details', 'Update Vehicle Settings']) {
    testWidgets('$action can complete after leaving the profile', (
      tester,
    ) async {
      final service = PendingProfileService();
      final user = UserEntity(
        uid: 'driver',
        role: UserRole.driver,
        fullName: 'Example Driver',
        email: 'driver@example.test',
        phone: '08012345678',
        vehiclePlateNumber: 'TEST-123',
        vehicleModel: 'Test motorcycle',
        createdAt: DateTime(2026),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProfileProvider.overrideWith(
              (ref) => Stream.value(user),
            ),
            authRemoteServiceProvider.overrideWithValue(service),
          ],
          child: const MaterialApp(home: ProfileScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(action));
      await tester.tap(find.text(action));
      await tester.pump();
      expect(service.called, isTrue);

      await tester.pumpWidget(const SizedBox.shrink());
      service.result.complete(right(unit));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }
}
