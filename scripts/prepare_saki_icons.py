from pathlib import Path
from PIL import Image

root = Path(__file__).resolve().parents[1]
source = root / 'assets' / 'saki_icon_concept_a.png'
image = Image.open(source).convert('RGBA')
# Android legacy launcher icon sizes for the existing mipmap folders.
sizes = {
    'mipmap-mdpi': 48,
    'mipmap-hdpi': 72,
    'mipmap-xhdpi': 96,
    'mipmap-xxhdpi': 144,
    'mipmap-xxxhdpi': 192,
}
for folder, size in sizes.items():
    output = root / 'android' / 'app' / 'src' / 'main' / 'res' / folder / 'ic_launcher.png'
    output.parent.mkdir(parents=True, exist_ok=True)
    image.resize((size, size), Image.Resampling.LANCZOS).save(output, optimize=True)
print('Prepared Android launcher icons from', source)
