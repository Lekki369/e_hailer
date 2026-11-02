#!/usr/bin/env python3
"""Install a pinned, checksum-verified scanner into ignored local tooling."""
import hashlib
import io
import platform
from pathlib import Path
import tarfile
import urllib.request

VERSION = '8.30.1'
ROOT = Path(__file__).resolve().parent.parent


def main():
    system = {'Darwin': 'darwin', 'Linux': 'linux'}.get(platform.system())
    arch = {'x86_64': 'x64', 'AMD64': 'x64', 'arm64': 'arm64', 'aarch64': 'arm64'}.get(platform.machine())
    if not system or not arch:
        raise SystemExit('Install the pinned Gitleaks version manually for this platform.')
    name = f'gitleaks_{VERSION}_{system}_{arch}.tar.gz'
    base = f'https://github.com/gitleaks/gitleaks/releases/download/v{VERSION}/'

    def fetch(filename):
        request = urllib.request.Request(base + filename, headers={'User-Agent': 'e-Hailer-security-check'})
        with urllib.request.urlopen(request, timeout=45) as response:
            return response.read()

    checksums = fetch(f'gitleaks_{VERSION}_checksums.txt').decode()
    expected = next(line.split()[0] for line in checksums.splitlines() if line.split()[-1] == name)
    data = fetch(name)
    if hashlib.sha256(data).hexdigest() != expected:
        raise SystemExit('Gitleaks archive checksum mismatch.')
    with tarfile.open(fileobj=io.BytesIO(data), mode='r:gz') as archive:
        member = archive.getmember('gitleaks')
        if not member.isfile():
            raise SystemExit('Invalid scanner archive.')
        destination = ROOT / '.cache/security-tools/gitleaks'
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(archive.extractfile(member).read())
        destination.chmod(0o700)
    print(f'Installed Gitleaks {VERSION}; official archive checksum verified.')


if __name__ == '__main__':
    main()
