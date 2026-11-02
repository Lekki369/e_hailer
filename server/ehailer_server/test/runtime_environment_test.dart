import 'package:ehailer_server/src/core/infrastructure/runtime_environment.dart';
import 'package:test/test.dart';

void main() {
  const demo = {
    'FIREBASE_PROJECT_ID': 'demo-ehailer',
    'FIRESTORE_EMULATOR_HOST': '127.0.0.1:8080',
    'FIREBASE_AUTH_EMULATOR_HOST': '127.0.0.1:9099',
  };
  test('mixed emulator identity/storage always fails closed', () {
    for (final key in [
      'FIRESTORE_EMULATOR_HOST',
      'FIREBASE_AUTH_EMULATOR_HOST',
    ]) {
      expect(
        () => validateRuntimeEnvironment({
          'FIREBASE_PROJECT_ID': 'production',
          key: '127.0.0.1:8080',
        }),
        throwsStateError,
      );
      final incomplete = {...demo}..remove(key);
      expect(() => validateRuntimeEnvironment(incomplete), throwsStateError);
    }
    expect(() => validateRuntimeEnvironment(demo), returnsNormally);
  });
  test('test keys cannot fund an unspecified real Firebase project', () {
    expect(
      () => validateRuntimeEnvironment({
        'FIREBASE_PROJECT_ID': 'production',
        'PAYSTACK_SECRET_KEY': 'sk_test_fixture',
      }),
      throwsStateError,
    );
    expect(
      () => validateRuntimeEnvironment({
        ...demo,
        'PAYSTACK_SECRET_KEY': 'sk_test_fixture',
      }),
      returnsNormally,
    );
    expect(
      () => validateRuntimeEnvironment({
        'FIREBASE_PROJECT_ID': 'isolated-staging',
        'PAYSTACK_TEST_PROJECT_ID': 'isolated-staging',
        'PAYSTACK_SECRET_KEY': 'sk_test_fixture',
      }),
      returnsNormally,
    );
  });
  test('live mode rejects emulators and mismatched keys', () {
    expect(
      () => validateRuntimeEnvironment({
        ...demo,
        'PAYSTACK_MODE': 'live',
        'PAYSTACK_SECRET_KEY': 'sk_live_fixture',
      }),
      throwsStateError,
    );
    expect(
      () => validateRuntimeEnvironment({
        'FIREBASE_PROJECT_ID': 'production',
        'PAYSTACK_MODE': 'live',
        'PAYSTACK_SECRET_KEY': 'sk_test_fixture',
      }),
      throwsStateError,
    );
  });
  test('provider override is restricted to demo loopback stubs', () {
    for (final base in [
      'https://attacker.example',
      'http://remote.example',
      'http://user:pass@localhost/',
      'http://localhost/?secret=1',
    ]) {
      expect(
        () => validateRuntimeEnvironment({
          ...demo,
          'PAYSTACK_SECRET_KEY': 'sk_test_fixture',
          'PAYSTACK_BASE_URL': base,
        }),
        throwsStateError,
      );
    }
    expect(
      () => validateRuntimeEnvironment({
        ...demo,
        'PAYSTACK_SECRET_KEY': 'sk_test_fixture',
        'PAYSTACK_BASE_URL': 'http://127.0.0.1:8899/',
      }),
      returnsNormally,
    );
  });
}
