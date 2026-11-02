#!/usr/bin/env python3
"""Build/run with an allowlisted local env and matching ignored native config."""
import argparse
import json
import os
from pathlib import Path
import plistlib
import re
import subprocess
import sys
import tempfile
from urllib.parse import unquote, urljoin, urlsplit
from env_config import ROOT, ConfigError, read_env, client_config, check_flutter_arguments, private_write


def write_native(values, root=ROOT):
    android_package = values.get('FIREBASE_ANDROID_PACKAGE_NAME', 'com.example.e_hailer')
    ios_bundle = values.get('FIREBASE_IOS_BUNDLE_ID', 'com.example.eHailer')
    android = {
        'project_info': {
            'project_number': values['FIREBASE_MESSAGING_SENDER_ID'],
            'project_id': values['FIREBASE_PROJECT_ID'],
            'storage_bucket': values.get('FIREBASE_STORAGE_BUCKET', ''),
        },
        'client': [{
            'client_info': {
                'mobilesdk_app_id': values['FIREBASE_ANDROID_APP_ID'],
                'android_client_info': {'package_name': android_package},
            },
            'oauth_client': [],
            'api_key': [{'current_key': values['FIREBASE_ANDROID_API_KEY']}],
            'services': {'appinvite_service': {'other_platform_oauth_client': []}},
        }],
        'configuration_version': '1',
    }
    ios = {
        'API_KEY': values['FIREBASE_IOS_API_KEY'],
        'GCM_SENDER_ID': values['FIREBASE_MESSAGING_SENDER_ID'],
        'PLIST_VERSION': '1', 'BUNDLE_ID': ios_bundle,
        'PROJECT_ID': values['FIREBASE_PROJECT_ID'],
        'STORAGE_BUCKET': values.get('FIREBASE_STORAGE_BUCKET', ''),
        'IS_ADS_ENABLED': False, 'IS_ANALYTICS_ENABLED': False,
        'IS_APPINVITE_ENABLED': False, 'IS_GCM_ENABLED': True,
        'IS_SIGNIN_ENABLED': True, 'GOOGLE_APP_ID': values['FIREBASE_IOS_APP_ID'],
    }
    private_write(root / 'android/app/google-services.json', (json.dumps(android, indent=2) + '\n').encode())
    private_write(root / 'ios/Runner/GoogleService-Info.plist', plistlib.dumps(ios))


def write_web(values, root=ROOT):
    package_config = root / '.dart_tool/package_config.json'
    if not package_config.is_file():
        raise ConfigError('Run flutter pub get before preparing web configuration.')
    packages = json.loads(package_config.read_text())['packages']
    package = next((p for p in packages if p['name'] == 'firebase_core_web'), None)
    if package is None:
        raise ConfigError('firebase_core_web is missing from resolved packages.')
    uri = urlsplit(urljoin(package_config.as_uri(), package['rootUri']))
    source = Path(unquote(uri.path)) / 'lib/src/firebase_sdk_version.dart'
    match = re.search(r"supportedFirebaseJsSdkVersion\s*=\s*'([0-9]+\.[0-9]+\.[0-9]+)'", source.read_text())
    if match is None:
        raise ConfigError('Review the installed FlutterFire web SDK version before building.')
    config = {field: values.get(key, '') for field, key in {
        'apiKey': 'FIREBASE_WEB_API_KEY', 'appId': 'FIREBASE_WEB_APP_ID',
        'messagingSenderId': 'FIREBASE_MESSAGING_SENDER_ID',
        'projectId': 'FIREBASE_PROJECT_ID', 'authDomain': 'FIREBASE_WEB_AUTH_DOMAIN',
        'storageBucket': 'FIREBASE_STORAGE_BUCKET',
    }.items()}
    content = '// Generated PUBLIC client configuration. Never add server secrets.\n'
    content += 'self.E_HAILER_FIREBASE_CONFIG = ' + json.dumps(config) + ';\n'
    content += 'self.E_HAILER_FIREBASE_SDK_VERSION = ' + json.dumps(match[1]) + ';\n'
    content += 'self.E_HAILER_FIREBASE_EMULATORS = ' + str(values.get('USE_FIREBASE_EMULATORS') == 'true').lower() + ';\n'
    private_write(root / 'web/firebase-client-config.js', content.encode())


def signing_environment(command, environment, root=ROOT):
    if command[:2] not in [['build', 'apk'], ['build', 'appbundle']] or '--debug' in command or '--profile' in command:
        return environment
    keys = {'E_HAILER_ANDROID_STORE_FILE', 'E_HAILER_ANDROID_STORE_PASSWORD',
            'E_HAILER_ANDROID_KEY_ALIAS', 'E_HAILER_ANDROID_KEY_PASSWORD'}
    path = root / 'android/.env'
    values = read_env(path) if path.is_file() else {}
    if set(values) - keys:
        raise ConfigError('android/.env may contain only Android signing settings.')
    merged = {**values, **environment}
    if any(not merged.get(key) for key in keys):
        raise ConfigError('Release Android builds require private signing settings in android/.env or process environment.')
    return merged


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--env', default='.env')
    parser.add_argument('--configure-only', action='store_true')
    parser.add_argument('flutter', nargs=argparse.REMAINDER)
    args = parser.parse_args()
    try:
        values = client_config(read_env(ROOT / args.env))
        command = args.flutter
        if command[:1] == ['--']:
            command = command[1:]
        if not args.configure_only:
            check_flutter_arguments(command, values)
        environment = {k: v for k, v in os.environ.items()
                       if not k.startswith('PAYSTACK_') and k not in {'GOOGLE_APPLICATION_CREDENTIALS', 'DART_DEFINES'}}
        environment = signing_environment(command, environment)
        write_native(values)
        write_web(values)
        if args.configure_only:
            print('Generated ignored Android/iOS/web configuration. Values withheld.')
            return 0
        folder = ROOT / '.cache/flutter-config'
        folder.mkdir(parents=True, exist_ok=True)
        fd, filename = tempfile.mkstemp(prefix='client-', suffix='.json', dir=folder)
        with os.fdopen(fd, 'w') as out:
            json.dump(values, out)
        try:
            # analyze does not accept Dart defines; still validates env/native files.
            define = [] if command[0] == 'analyze' else [f'--dart-define-from-file={filename}']
            return subprocess.call(['flutter', *command, *define], cwd=ROOT, env=environment)
        finally:
            os.unlink(filename)
    except (ConfigError, OSError) as error:
        print(f'Configuration failed: {error}', file=sys.stderr)
        return 2


if __name__ == '__main__':
    sys.exit(main())
