"""Create private local settings without overwriting an existing encryption key."""
import os
import secrets
from pathlib import Path

root = Path(__file__).resolve().parents[1]
target = root / '.env'
if target.exists():
    values = dict(line.split('=', 1) for line in target.read_text().splitlines() if '=' in line and not line.startswith('#'))
    for key in ('POSTGRES_PASSWORD', 'N8N_ENCRYPTION_KEY', 'CAREERFLOW_WORKFLOW_TOKEN'):
        value = values.get(key, '')
        if len(value) < 24 or value.startswith('replace-'):
            raise SystemExit(f'Existing .env needs {key} configured locally. No values changed.')
    print('Existing configuration validated; encryption key preserved.')
else:
    data = ''.join(f'{key}={secrets.token_urlsafe(32)}\n' for key in
                   ('POSTGRES_PASSWORD', 'N8N_ENCRYPTION_KEY', 'CAREERFLOW_WORKFLOW_TOKEN'))
    descriptor = os.open(target, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
    with os.fdopen(descriptor, 'w') as stream:
        stream.write(data)
    print('Created private .env. Values were not printed.')
