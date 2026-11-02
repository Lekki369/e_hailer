import json
import os
from pathlib import Path
import plistlib
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from env_config import ConfigError, client_config, read_env, check_flutter_arguments
from flutter_env import write_native, write_web, signing_environment
from check_secrets import inspect


class EnvironmentTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)

    def load(self, text):
        path = self.root / '.env'
        path.write_text(text)
        return read_env(path)

    def test_dotenv_and_flat_json_have_identical_values(self):
        self.assertEqual(self.load('USE_FIREBASE_EMULATORS=true\nEMPTY=\nURL="https://example.test/a?b=c"'),
                         self.load(json.dumps({'USE_FIREBASE_EMULATORS': True, 'EMPTY': '', 'URL': 'https://example.test/a?b=c'})))

    def test_duplicate_or_expanding_configuration_is_rejected(self):
        for text in ['VALUE=a\nVALUE=b', '{"VALUE":"a","VALUE":"b"}',
                     'VALUE=$(touch /tmp/never-executed)', 'VALUE=${SECRET}',
                     'VALUE=`command`', '{"VALUE":{"nested":"data"}}']:
            with self.subTest(text=text), self.assertRaises(ConfigError):
                self.load(text)

    def test_private_keys_cannot_be_compiled_under_any_setting(self):
        for key in ['PAYSTACK_SECRET_KEY', 'GOOGLE_APPLICATION_CREDENTIALS', 'SIGNING_PASSWORD']:
            with self.subTest(key=key), self.assertRaises(ConfigError):
                client_config({'USE_FIREBASE_EMULATORS': 'true', key: 'private'})
        with self.assertRaises(ConfigError):
            client_config({'FIREBASE_WEB_API_KEY': 'sk_' + 'test_fixture'})

    def test_release_requires_real_complete_configuration(self):
        with self.assertRaises(ConfigError):
            client_config({'USE_FIREBASE_EMULATORS': 'false'})
        with self.assertRaises(ConfigError):
            client_config({'USE_FIREBASE_EMULATORS': 'true', 'FIREBASE_PROJECT_ID': 'real-project'})
        demo = client_config({'USE_FIREBASE_EMULATORS': 'true'})
        for command in [['build', 'web'], ['build', 'apk', '--release'], ['run', '--profile']]:
            with self.assertRaises(ConfigError):
                check_flutter_arguments(command, demo)
        check_flutter_arguments(['build', 'apk', '--debug'], demo)

    def test_define_overrides_cannot_bypass_validation(self):
        for arg in ['--dart-define=PRIVATE=value', '--dart-define-from-file=server/.env']:
            with self.assertRaises(ConfigError):
                check_flutter_arguments(['build', 'web', arg], {})

    def test_credentials_in_urls_and_nonlocal_http_are_rejected(self):
        for url in ['https://user:pass@example.test', 'https://example.test/?key=value',
                    'https://example.test/#token', 'http://remote.example.test']:
            with self.assertRaises(ConfigError):
                client_config({'USE_FIREBASE_EMULATORS': 'true', 'E_HAILER_API_URL': url})
        client_config({'USE_FIREBASE_EMULATORS': 'true', 'E_HAILER_API_URL': 'http://10.0.2.2:8787/'})

    def test_native_and_worker_configuration_match_the_validated_environment(self):
        values = client_config({'USE_FIREBASE_EMULATORS': 'true'})
        write_native(values, self.root)
        android = json.loads((self.root / 'android/app/google-services.json').read_text())
        ios = plistlib.loads((self.root / 'ios/Runner/GoogleService-Info.plist').read_bytes())
        self.assertEqual(android['project_info']['project_id'], ios['PROJECT_ID'])
        self.assertEqual(ios['GOOGLE_APP_ID'], values['FIREBASE_IOS_APP_ID'])
        package = self.root / 'sdk/lib/src'
        package.mkdir(parents=True)
        (package / 'firebase_sdk_version.dart').write_text("const String supportedFirebaseJsSdkVersion = '13.1.0';")
        config = self.root / '.dart_tool/package_config.json'
        config.parent.mkdir()
        config.write_text(json.dumps({'packages': [{'name': 'firebase_core_web', 'rootUri': '../sdk'}]}))
        write_web(values, self.root)
        worker = (self.root / 'web/firebase-client-config.js').read_text()
        self.assertIn('"13.1.0"', worker)
        self.assertIn('demo-ehailer', worker)
        self.assertIn('EMULATORS = true', worker)
        if os.name != 'nt':
            self.assertEqual((self.root / 'web/firebase-client-config.js').stat().st_mode & 0o777, 0o600)

    def test_release_signing_is_required_and_not_a_dart_define(self):
        with self.assertRaises(ConfigError):
            signing_environment(['build', 'apk'], {}, self.root)
        self.assertEqual(signing_environment(['build', 'apk', '--debug'], {}, self.root), {})

    def test_publish_guard_rejects_private_files_and_credential_contents(self):
        for path in ['.env', '.env.staging', 'server/.env', 'android/app/google-services.json', 'key.p12']:
            self.assertTrue(inspect(path, b''))
        self.assertFalse(inspect('.env.example', b'PAYSTACK_SECRET_KEY=\n'))
        self.assertTrue(inspect('app.dart', ('AIza' + 'a' * 35).encode()))
        self.assertTrue(inspect('config.json', b'{"type":"service_account"}'))


if __name__ == '__main__':
    unittest.main()
