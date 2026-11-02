"""Parse local configuration without shell evaluation or secret-bearing errors."""
import json
import os
from pathlib import Path
import re
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parent.parent
CLIENT_KEYS = frozenset({
    'USE_FIREBASE_EMULATORS', 'FIREBASE_EMULATOR_HOST',
    'FIREBASE_PROJECT_ID', 'FIREBASE_MESSAGING_SENDER_ID',
    'FIREBASE_STORAGE_BUCKET', 'FIREBASE_WEB_API_KEY', 'FIREBASE_WEB_APP_ID',
    'FIREBASE_WEB_AUTH_DOMAIN', 'FIREBASE_WEB_MEASUREMENT_ID',
    'FIREBASE_ANDROID_API_KEY', 'FIREBASE_ANDROID_APP_ID',
    'FIREBASE_ANDROID_PACKAGE_NAME', 'FIREBASE_IOS_API_KEY',
    'FIREBASE_IOS_APP_ID', 'FIREBASE_IOS_BUNDLE_ID',
    'E_HAILER_API_URL', 'E_HAILER_PUBLIC_URL', 'OSRM_BASE_URL',
    'NOMINATIM_BASE_URL',
})
SECRET_VALUE = re.compile(
    r'(?:-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----|'
    r'\b(?:sk|rk)_(?:test|live)_[A-Za-z0-9]+|'
    r'\b(?:ghp_|github_pat_)[A-Za-z0-9_]+|'
    r'\bAKIA[A-Z0-9]{16}\b|\beyJ[A-Za-z0-9_-]+\.eyJ[A-Za-z0-9_-]+\.)'
)


class ConfigError(ValueError):
    pass


def read_env(path):
    """Support flat JSON or simple dotenv; never expand variables or run a shell."""
    path = Path(path)
    if not path.is_file() or path.stat().st_size > 65536:
        raise ConfigError('Configuration must be an existing file under 64 KiB.')
    raw = path.read_text()
    values = {}

    def add(key, value):
        if not isinstance(key, str) or not re.fullmatch(r'[A-Z][A-Z0-9_]*', key):
            raise ConfigError('Configuration contains an invalid key name.')
        if key in values:
            raise ConfigError(f'Duplicate configuration key: {key}')
        if isinstance(value, bool):
            value = str(value).lower()
        if not isinstance(value, str) or '\n' in value or '\r' in value or '\0' in value:
            raise ConfigError(f'Configuration value must be a single-line string: {key}')
        if '${' in value or '$(' in value or '`' in value:
            raise ConfigError(f'Shell expansion is not supported: {key}')
        values[key] = value

    try:
        if raw.lstrip().startswith('{'):
            pairs = json.loads(raw, object_pairs_hook=lambda entries: entries)
            if not isinstance(pairs, list):
                raise ConfigError('Configuration JSON must be a flat object.')
            for key, value in pairs:
                add(key, value)
        else:
            for number, raw_line in enumerate(raw.splitlines(), 1):
                line = raw_line.strip()
                if not line or line.startswith('#'):
                    continue
                if '=' not in line:
                    raise ConfigError(f'Expected KEY=value on line {number}.')
                key, value = line.split('=', 1)
                key, value = key.strip(), value.strip()
                if value.startswith('"'):
                    value = json.loads(value)
                elif value.startswith("'"):
                    if len(value) < 2 or not value.endswith("'"):
                        raise ConfigError(f'Unclosed quote on line {number}.')
                    value = value[1:-1]
                else:
                    value = value.split(' #', 1)[0].rstrip()
                add(key, value)
    except (json.JSONDecodeError, TypeError, ValueError) as error:
        if isinstance(error, ConfigError):
            raise
        raise ConfigError('Invalid configuration syntax; values are withheld.') from None
    return values


def client_config(values):
    unknown = sorted(set(values) - CLIENT_KEYS)
    if unknown:
        raise ConfigError('Non-client keys are forbidden in Flutter defines: ' + ', '.join(unknown))
    for key, value in values.items():
        if SECRET_VALUE.search(value):
            raise ConfigError(f'A server credential or token cannot be compiled into Flutter: {key}')
    emulator = values.get('USE_FIREBASE_EMULATORS', 'false')
    if emulator not in {'true', 'false'}:
        raise ConfigError('USE_FIREBASE_EMULATORS must be true or false.')
    result = dict(values)
    if emulator == 'true':
        if values.get('FIREBASE_PROJECT_ID', 'demo-ehailer') != 'demo-ehailer':
            raise ConfigError('Client emulators require FIREBASE_PROJECT_ID=demo-ehailer.')
        result.update({
            'FIREBASE_PROJECT_ID': 'demo-ehailer',
            'FIREBASE_MESSAGING_SENDER_ID': '123456789',
            'FIREBASE_WEB_APP_ID': '1:123456789:web:0000000000000000000000',
            'FIREBASE_ANDROID_APP_ID': '1:123456789:android:0000000000000000000000',
            'FIREBASE_IOS_APP_ID': '1:123456789:ios:0000000000000000000000',
            'FIREBASE_WEB_API_KEY': 'emulator-key',
            'FIREBASE_ANDROID_API_KEY': 'emulator-key',
            'FIREBASE_IOS_API_KEY': 'emulator-key',
            'FIREBASE_STORAGE_BUCKET': '',
            'FIREBASE_WEB_AUTH_DOMAIN': '',
            'FIREBASE_WEB_MEASUREMENT_ID': '',
        })
    else:
        required = {'FIREBASE_PROJECT_ID', 'FIREBASE_MESSAGING_SENDER_ID',
                    'FIREBASE_WEB_API_KEY', 'FIREBASE_WEB_APP_ID',
                    'FIREBASE_ANDROID_API_KEY', 'FIREBASE_ANDROID_APP_ID',
                    'FIREBASE_IOS_API_KEY', 'FIREBASE_IOS_APP_ID'}
        missing = sorted(key for key in required if not result.get(key))
        if missing:
            raise ConfigError('Missing client configuration: ' + ', '.join(missing))
    for key in ['E_HAILER_API_URL', 'E_HAILER_PUBLIC_URL', 'OSRM_BASE_URL', 'NOMINATIM_BASE_URL']:
        if not result.get(key):
            continue
        try:
            uri = urlsplit(result[key])
            local = emulator == 'true' and uri.hostname in {'localhost', '127.0.0.1', '10.0.2.2'}
            valid = uri.hostname and not uri.username and not uri.password and not uri.query and not uri.fragment
            valid = valid and (uri.scheme == 'https' or (local and uri.scheme == 'http'))
        except ValueError:
            valid = False
        if not valid:
            raise ConfigError(f'Use HTTPS without credentials, query or fragment: {key}')
    return result


def check_flutter_arguments(arguments, values):
    if not arguments or arguments[0] not in {'run', 'build', 'test', 'analyze'}:
        raise ConfigError('Expected a Flutter run, build, test or analyze command.')
    if any(arg.split('=', 1)[0] in {'--dart-define', '--dart-define-from-file'} for arg in arguments):
        raise ConfigError('Pass configuration through --env; unchecked define overrides are forbidden.')
    if values.get('USE_FIREBASE_EMULATORS') == 'true':
        release = '--release' in arguments or '--profile' in arguments
        release = release or (arguments[0] == 'build' and '--debug' not in arguments)
        if release:
            raise ConfigError('Emulator configuration is restricted to debug builds.')


def private_write(path, content):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.is_symlink():
        raise ConfigError('Refusing to replace a configuration symlink.')
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    os.fchmod(fd, 0o600)
    with os.fdopen(fd, 'wb') as stream:
        stream.write(content)
