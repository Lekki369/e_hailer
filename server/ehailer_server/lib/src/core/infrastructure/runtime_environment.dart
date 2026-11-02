/// Fail closed for mixed real/emulated identity and for sandbox wallet funding.
void validateRuntimeEnvironment(Map<String, String> env) {
  final project = env['FIREBASE_PROJECT_ID'] ?? '';
  if (project.isEmpty) {
    throw StateError('Set FIREBASE_PROJECT_ID before starting the API.');
  }
  final firestore = env['FIRESTORE_EMULATOR_HOST'];
  final auth = env['FIREBASE_AUTH_EMULATOR_HOST'];
  final emulator = firestore != null || auth != null;
  if ((emulator || project.startsWith('demo-')) &&
      (!project.startsWith('demo-') ||
          firestore == null ||
          firestore.isEmpty ||
          auth == null ||
          auth.isEmpty)) {
    throw StateError(
      'Emulators require a demo- project and both Firestore and Auth emulator hosts.',
    );
  }
  final secret = env['PAYSTACK_SECRET_KEY'];
  if (secret == null || secret.isEmpty) return;
  final mode = env['PAYSTACK_MODE'] ?? 'test';
  if (!{'test', 'live'}.contains(mode) || !secret.startsWith('sk_${mode}_')) {
    throw StateError(
      'PAYSTACK_MODE must match the configured server secret key.',
    );
  }
  if (mode == 'live' && emulator) {
    throw StateError('Live payments cannot use Firebase emulators.');
  }
  if (mode == 'test' &&
      !emulator &&
      env['PAYSTACK_TEST_PROJECT_ID'] != project) {
    throw StateError(
      'Test payments require emulators or an explicitly isolated PAYSTACK_TEST_PROJECT_ID.',
    );
  }
  final callback = env['PAYSTACK_CALLBACK_URL'];
  if (callback != null) {
    final uri = Uri.tryParse(callback);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      throw StateError('PAYSTACK_CALLBACK_URL must be a trusted HTTPS URL.');
    }
  }
  final base = env['PAYSTACK_BASE_URL'];
  if (base != null) {
    final uri = Uri.tryParse(base);
    if (!emulator ||
        mode != 'test' ||
        uri == null ||
        uri.scheme != 'http' ||
        !{'localhost', '127.0.0.1'}.contains(uri.host) ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        !{'', '/'}.contains(uri.path)) {
      throw StateError(
        'PAYSTACK_BASE_URL is restricted to a local stub with demo emulators.',
      );
    }
  }
}
