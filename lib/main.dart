import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/presentation/styles/app_assets.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'app.dart';
import 'firebase_options.dart';

bool _fontLicenseRegistered = false;

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!_fontLicenseRegistered) {
    LicenseRegistry.addLicense(() async* {
      final text = await rootBundle.loadString(AppAssets.interfaceFontLicense);
      yield LicenseEntryWithLineBreaks(['Plus Jakarta Sans'], text);
    });
    _fontLicenseRegistered = true;
  }
  try {
    const emulators = bool.fromEnvironment('USE_FIREBASE_EMULATORS');
    if (emulators && !kDebugMode) {
      throw StateError('Emulators are available only in debug builds.');
    }
    final options = DefaultFirebaseOptions.currentPlatform;
    if (Firebase.apps.isEmpty) await Firebase.initializeApp(options: options);
    if (emulators) {
      const host = String.fromEnvironment(
        'FIREBASE_EMULATOR_HOST',
        defaultValue: '127.0.0.1',
      );
      await FirebaseAuth.instance.useAuthEmulator(host, 9099);
      FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
    }
    if (!kIsWeb && !emulators) {
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );
    }
    runApp(const ProviderScope(child: EHailerApp()));
  } catch (_) {
    runApp(
      MaterialApp(
        home: Scaffold(
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off_outlined, size: 48),
                    const SizedBox(height: 16),
                    const Text(
                      'We could not start e-Hailer.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Please check your connection and try again.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    FilledButton(onPressed: main, child: const Text('Retry')),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
