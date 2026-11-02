#!/usr/bin/env python3
"""Reject private files and known credential patterns without printing values."""
import argparse
from pathlib import Path
import re
import subprocess
import sys
from env_config import ROOT, SECRET_VALUE

PRIVATE_NAMES = {
    '.firebaserc', 'google-services.json', 'GoogleService-Info.plist',
    'firebase-client-config.js', 'key.properties', 'passwords.yaml',
}
PRIVATE_SUFFIXES = {'.pem', '.p12', '.p8', '.jks', '.keystore', '.mobileprovision'}
PUBLIC_KEY = re.compile(r'AIza[0-9A-Za-z_-]{35}')
SERVICE_ACCOUNT = re.compile(r'"type"\s*:\s*"service_account"')


def inspect(path, data):
    """Only return finding labels; never include matched content."""
    name = Path(path).name
    private_env = (name == '.env' or name.startswith('.env.')) and name != '.env.example'
    if private_env or name in PRIVATE_NAMES or Path(name).suffix in PRIVATE_SUFFIXES:
        return ['private configuration or signing file']
    if any(part in {'.firebase_local', '.cache'} for part in Path(path).parts):
        return ['local-only directory']
    text = data.decode('utf-8', errors='replace')
    found = []
    if PUBLIC_KEY.search(text):
        found.append('Firebase/Google key must remain in local configuration')
    secrets = [match.group(0) for match in SECRET_VALUE.finditer(text)]
    if path.startswith('server/ehailer_server/test/') or path == 'tool/check_secrets.py':
        secrets = [value for value in secrets if value not in {'sk_test_fixture', 'sk_live_fixture'}]
    if secrets:
        found.append('credential or token pattern')
    if path.endswith('.json') and SERVICE_ACCOUNT.search(text):
        found.append('service-account credential document')
    return found


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--staged', action='store_true', help='Inspect complete index bytes, not working copies.')
    args = parser.parse_args()
    command = ['git', 'ls-files', '-z']
    if not args.staged:
        command += ['--cached', '--others', '--exclude-standard']
    paths = sorted(set(subprocess.check_output(command, cwd=ROOT).split(b'\0')) - {b''})
    failures = 0
    checked = 0
    for raw in paths:
        path = raw.decode('utf-8')
        if args.staged:
            data = subprocess.check_output(['git', 'show', ':' + path], cwd=ROOT)
        else:
            source = ROOT / path
            if not source.is_file():
                continue
            if source.is_symlink():
                print(f'{path}: review symlink before publishing')
                failures += 1
                continue
            data = source.read_bytes()
        checked += 1
        for label in inspect(path, data):
            print(f'{path}: {label}')
            failures += 1
    print(f'Checked {checked} publishable files; {failures} finding(s). Values withheld.')
    return 1 if failures else 0


if __name__ == '__main__':
    sys.exit(main())
