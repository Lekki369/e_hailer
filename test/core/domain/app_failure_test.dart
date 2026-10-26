import 'package:flutter_test/flutter_test.dart';
import 'package:e_hailer/core/domain/failures/app_failure.dart';

void main() {
  group('AppFailure Hierarchy & Equatable Equality', () {
    test('ServerFailure preserves error message and optional code', () {
      const failure = ServerFailure(message: 'Internal server error', code: 500);

      expect(failure.message, equals('Internal server error'));
      expect(failure.code, equals(500));
      expect(failure, equals(const ServerFailure(message: 'Internal server error', code: 500)));
    });

    test('NetworkFailure has sensible default message', () {
      const failure = NetworkFailure();
      expect(failure.message, equals('No internet connection detected.'));
    });

    test('AuthFailure holds failure explanation', () {
      const failure = AuthFailure(message: 'Invalid email or password.');
      expect(failure.message, equals('Invalid email or password.'));
    });

    test('Location failures have distinct default messages', () {
      const permFailure = LocationPermissionFailure();
      const serviceFailure = LocationServiceDisabledFailure();

      expect(permFailure.message, contains('Location permission is denied'));
      expect(serviceFailure.message, contains('Location services are disabled'));
      expect(permFailure == serviceFailure, isFalse);
    });

    test('InvalidOtpFailure verifies 4-digit PIN verification failure', () {
      const failure = InvalidOtpFailure();
      expect(failure.message, contains('Invalid 4-digit handover verification PIN'));
    });

    test('OrderNotFoundFailure informs missing delivery document', () {
      const failure = OrderNotFoundFailure();
      expect(failure.message, contains('Delivery order not found'));
    });

    test('UnexpectedFailure handles general exceptions', () {
      const failure = UnexpectedFailure();
      expect(failure.message, equals('An unexpected error occurred.'));
    });
  });
}
