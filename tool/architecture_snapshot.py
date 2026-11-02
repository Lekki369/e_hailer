#!/usr/bin/env python3
"""Pin cited working-tree bytes in an isolated local Git evidence repository.

Never touches the application repository's branch, index, or commit history.
Re-run after reviewing line ranges whenever a cited file changes.
"""
import hashlib
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
from urllib.parse import urlsplit, urlunsplit

ROOT = Path(__file__).resolve().parent.parent
SNAPSHOT = ROOT / '.cache/architecture-source'


def git(*args, cwd=ROOT):
    return subprocess.check_output(['git', *args], cwd=cwd, text=True).strip()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('candidate', nargs='?', default='docs/architecture.json')
    candidate_path = (ROOT / parser.parse_args().candidate).resolve()
    if not candidate_path.is_relative_to(ROOT):
        raise ValueError('Candidate must be inside the repository.')
    candidate = json.loads(candidate_path.read_text())
    paths = sorted({source['path'] for component in candidate['components']
                    for source in component['sources']})
    origin = git('remote', 'get-url', 'origin')
    url = urlsplit(origin)
    if url.scheme in {'http', 'https'}:
        origin = urlunsplit((url.scheme, url.netloc.rsplit('@', 1)[-1],
                            url.path, '', ''))
    SNAPSHOT.mkdir(parents=True, exist_ok=True)
    if not (SNAPSHOT / '.git').exists():
        git('init', '-q', cwd=SNAPSHOT)
        git('remote', 'add', 'origin', origin, cwd=SNAPSHOT)
    hashes = {}
    for relative in paths:
        source = (ROOT / relative).resolve()
        if not source.is_relative_to(ROOT) or not source.is_file():
            raise ValueError(f'Invalid source path: {relative}')
        target = SNAPSHOT / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, target)
        hashes[relative] = hashlib.sha256(source.read_bytes()).hexdigest()
    git('add', '--', *paths, cwd=SNAPSHOT)
    if git('status', '--porcelain', cwd=SNAPSHOT):
        env = {**os.environ, 'GIT_AUTHOR_DATE': '2026-10-30T00:00:00Z',
               'GIT_COMMITTER_DATE': '2026-10-30T00:00:00Z'}
        subprocess.run(['git', '-c', 'user.name=Architecture Evidence',
                        '-c', 'user.email=architecture@example.invalid',
                        'commit', '-q', '-m', 'Snapshot cited working-tree source'],
                       cwd=SNAPSHOT, env=env, check=True)
    revision = git('rev-parse', 'HEAD', cwd=SNAPSHOT)
    candidate['meta']['repository'] = {
        'url': origin, 'revision': revision, 'link_mode': 'local-only',
    }
    candidate_path.write_text(json.dumps(candidate, indent=2) + '\n')
    candidate_path.with_name(candidate_path.stem + '-evidence.json').write_text(json.dumps({
        'description': 'Local implementation source snapshot; not a deployed or upstream revision.',
        'base_revision': git('rev-parse', 'HEAD'),
        'snapshot_revision': revision,
        'snapshot_path': '.cache/architecture-source',
        'sha256': hashes,
    }, indent=2) + '\n')
    print(f'Pinned {len(paths)} cited files at local snapshot {revision}')


if __name__ == '__main__':
    main()
