#!/usr/bin/env python3
"""Create a self-contained source archive, excluding caches and build artifacts."""
import hashlib
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED

root = Path(__file__).resolve().parents[1]
destination = root / 'builds/RUBRO-fonte.zip'
destination.parent.mkdir(exist_ok=True)
files = [root / name for name in ('project.godot', 'export_presets.cfg', 'README.md', 'LICENSE', '.gitignore')]
for folder in ('assets', 'scenes', 'scripts', 'tests', 'tools', 'docs'):
    files.extend(p for p in (root / folder).rglob('*') if p.is_file() and '__pycache__' not in p.parts and p.suffix not in ('.pyc', '.log'))
with ZipFile(destination, 'w', ZIP_DEFLATED) as archive:
    for path in sorted(files):
        archive.write(path, Path('RUBRO') / path.relative_to(root))
with (root / 'builds/SHA256SUMS.txt').open('w') as manifest:
    for path in [root / 'builds/linux/RUBRO.x86_64', root / 'builds/windows/RUBRO.exe', root / 'builds/macos/RUBRO.zip', destination]:
        manifest.write(hashlib.sha256(path.read_bytes()).hexdigest() + '  ' + str(path.relative_to(root / 'builds')) + '\n')
print(destination)
