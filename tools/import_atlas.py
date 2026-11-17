#!/usr/bin/env python3
"""Extract the six original imagegen diffuse tiles; no runtime dependency."""
from pathlib import Path
from PIL import Image

root = Path(__file__).resolve().parents[1]
image = Image.open(root / 'assets/textures/source/military-atlas.png').convert('RGB')
width, height = image.width // 3, image.height // 2
for i, name in enumerate(('ground', 'concrete', 'metal', 'fabric', 'asphalt', 'camo')):
    x, y = (i % 3) * width, (i // 3) * height
    image.crop((x, y, x + width, y + height)).save(root / f'assets/textures/{name}-v2.png')
