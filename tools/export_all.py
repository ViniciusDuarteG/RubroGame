#!/usr/bin/env python3
"""Rebuild all desktop targets with an installed Godot 4.5.1 and export templates."""
import hashlib, pathlib, shutil, subprocess, sys
root=pathlib.Path(__file__).resolve().parents[1]
engine=sys.argv[1] if len(sys.argv)>1 else 'godot'
for preset,folder in [('Linux x64','linux'),('Windows x64','windows'),('macOS universal','macos')]:
    dest=root/'builds'/folder; dest.mkdir(parents=True,exist_ok=True)
    subprocess.run([engine,'--headless','--path',str(root),'--export-release',preset],cwd=root,check=True)
    shutil.copy2(root/'LICENSE',dest/'LICENSE.txt')
    shutil.copy2(root/'assets/GODOT-LICENSE.txt',dest/'GODOT-LICENSE.txt')
    shutil.copy2(root/'assets/DEJAVU-LICENSE.txt',dest/'DEJAVU-LICENSE.txt')
artifacts=[root/'builds/linux/RUBRO.x86_64',root/'builds/windows/RUBRO.exe',root/'builds/macos/RUBRO.zip']
with (root/'builds/SHA256SUMS.txt').open('w') as manifest:
    for artifact in artifacts:
        manifest.write(hashlib.sha256(artifact.read_bytes()).hexdigest()+'  '+str(artifact.relative_to(root/'builds'))+'\n')
print('Desktop builds complete.')
