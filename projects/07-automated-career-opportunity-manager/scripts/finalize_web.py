"""Fingerprint Flutter fonts after a web build so upgrades cannot reuse old glyph subsets."""
import hashlib
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1] / 'build' / 'web' / 'assets'
manifest = root / 'FontManifest.json'
families = json.loads(manifest.read_text(encoding='utf-8'))
for family in families:
    for font in family['fonts']:
        source = root / font['asset']
        content = source.read_bytes()
        digest = hashlib.sha256(content).hexdigest()[:16]
        target = source.with_name(source.stem.split('.v-')[0] + '.v-' + digest + source.suffix)
        target.write_bytes(content)
        font['asset'] = target.relative_to(root).as_posix()
manifest.write_text(json.dumps(families, separators=(',', ':')), encoding='utf-8')
print('Web fonts fingerprinted; new builds cannot reuse stale icon subsets.')
