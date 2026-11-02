#!/usr/bin/env python3
"""Load the private server env without evaluating shell commands."""
import argparse
import os
import subprocess
import sys
from env_config import ROOT, ConfigError, read_env


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--env', default='server/ehailer_server/.env')
    parser.add_argument('command', nargs=argparse.REMAINDER)
    args = parser.parse_args()
    try:
        values = read_env(ROOT / args.env)
        command = args.command
        if command[:1] == ['--']:
            command = command[1:]
        command = command or ['dart', 'run', 'bin/main.dart']
        # Explicit process/secret-manager settings take precedence over local defaults.
        return subprocess.call(command, cwd=ROOT / 'server/ehailer_server', env={**values, **os.environ})
    except (ConfigError, OSError) as error:
        print(f'Server configuration failed: {error}', file=sys.stderr)
        return 2


if __name__ == '__main__':
    sys.exit(main())
