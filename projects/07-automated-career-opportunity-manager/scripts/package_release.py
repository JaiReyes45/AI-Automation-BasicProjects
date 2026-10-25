"""Package public project source and the prebuilt client; never include runtime data.

Run from the canonical Git checkout after building Flutter. The resulting ZIP is
an installation kit, not a backup of the user's workspace.
"""
import hashlib
import json
import subprocess
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
VERSION = '1.0.0'


def main():
    repo = Path(subprocess.check_output(['git', 'rev-parse', '--show-toplevel'], cwd=ROOT, text=True).strip())
    relative = ROOT.relative_to(repo)
    paths = subprocess.check_output(
        ['git', 'ls-files', '--cached', '--others', '--exclude-standard', '-z', '--', str(relative)],
        cwd=repo,
    ).decode().split('\0')
    files = {}
    for name in paths:
        if not name:
            continue
        path = repo / name
        local = path.relative_to(ROOT)
        if any(part in {'.runtime', 'local-data', '.git', '.dart_tool', '__pycache__', 'build'} for part in local.parts):
            raise ValueError('Runtime file appeared in public source candidates')
        if path.name.startswith('.env') and path.name != '.env.example':
            raise ValueError('Private environment file appeared in source candidates')
        if path.is_symlink():
            raise ValueError('Release source cannot contain symlinks')
        if path.is_file():
            files[Path('projects') / ROOT.name / local] = path
    build = ROOT / 'build' / 'web'
    if not (build / 'index.html').is_file() or not (build / 'main.dart.js').is_file():
        raise ValueError('Build the Flutter web release first')
    for path in build.rglob('*'):
        if path.is_file() and not path.is_symlink():
            files[Path('projects') / ROOT.name / path.relative_to(ROOT)] = path
    settings = ROOT / '.env'
    secrets = []
    if settings.exists():
        secrets = [line.split('=', 1)[1].encode() for line in settings.read_text().splitlines()
                   if '=' in line and not line.startswith('#') and len(line.split('=', 1)[1]) > 10]
    payloads = {}
    for name, path in files.items():
        data = path.read_bytes()
        if any(secret in data for secret in secrets):
            raise ValueError('A local secret appeared in a release file')
        payloads[name.as_posix()] = data
    payloads['START_HERE.md'] = (
        '# CareerFlow local release ' + VERSION + '\n\n'
        'Open projects/07-automated-career-opportunity-manager/HANDOFF.md.\n'
        'Run its Docker commands from this extracted directory. The web build is included.\n'
        'Docker, Python 3 and an internet connection for initial images/Gmail are required.\n'
        'This kit contains no personal data or connected accounts. Follow the setup guide.\n'
    ).encode()
    manifest = dict(version=VERSION, sha256={name: hashlib.sha256(data).hexdigest() for name, data in sorted(payloads.items())})
    destination = ROOT / '.runtime' / 'releases'
    destination.mkdir(parents=True, exist_ok=True)
    archive = destination / ('careerflow-local-' + VERSION + '.zip')
    with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED) as output:
        for name, data in sorted(payloads.items()):
            output.writestr(name, data)
        output.writestr('RELEASE_MANIFEST.json', json.dumps(manifest, indent=2) + '\n')
    with zipfile.ZipFile(archive) as check:
        assert check.testzip() is None
        for name, digest in manifest['sha256'].items():
            assert hashlib.sha256(check.read(name)).hexdigest() == digest
    digest = hashlib.sha256(archive.read_bytes()).hexdigest()
    archive.with_suffix('.zip.sha256').write_text(digest + '  ' + archive.name + '\n')
    print(json.dumps(dict(archive=str(archive), files=len(payloads), bytes=archive.stat().st_size, sha256=digest), indent=2))


if __name__ == '__main__':
    main()
