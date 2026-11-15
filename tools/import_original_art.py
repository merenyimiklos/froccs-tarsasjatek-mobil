"""Extract the published Fröccs rulebook artwork (not webshop photographs).

Requires: python -m pip install pymupdf pillow
Usage: python tools/import_original_art.py path/to/rules.pdf
"""
import hashlib
import json
import sys
from pathlib import Path

import pymupdf
from PIL import Image, ImageDraw

SOURCE = 'https://saldokiado.hu/custom/saldowebshop/image/data/betekinto/tarsasjatekszabaly/_froccs-tarsasjatek.pdf'
OUT = Path(__file__).resolve().parents[1] / 'assets' / 'original'
SCALE = 8


def main():
    source = Path(sys.argv[1])
    doc = pymupdf.open(source)
    OUT.mkdir(parents=True, exist_ok=True)
    entries = []
    rendered = {}

    def extract(name, page, points, inset=2):
        # Restore the original rectangle from the four print-bleed corners.
        # Coordinates are TL, BL, BR, TR; no illustration is recreated.
        if page not in rendered:
            pix = doc[page].get_pixmap(matrix=pymupdf.Matrix(SCALE, SCALE))
            rendered[page] = Image.frombytes('RGB', (pix.width, pix.height), pix.samples)
        tl, bl, br, tr = [pymupdf.Point(p) for p in points]
        width, height = abs(tr - tl), abs(bl - tl)
        ux, uy = (tr - tl) / width, (bl - tl) / height
        corners = [tl + ux * inset + uy * inset,
                   bl + ux * inset - uy * inset,
                   br - ux * inset - uy * inset,
                   tr - ux * inset + uy * inset]
        size = (round((width - inset * 2) * SCALE),
                round((height - inset * 2) * SCALE))
        quad = tuple(value * SCALE for p in corners for value in p)
        image = rendered[page].transform(size, Image.Transform.QUAD, quad,
                                        Image.Resampling.BICUBIC)
        image.save(OUT / f'{name}.png', optimize=True)
        entries.append({'file': f'{name}.png', 'page': page + 1,
                        'size': list(size), 'source_corners': [list(p) for p in corners]})

    def from_drawing(name, page, index, inset=2):
        items = doc[page].get_drawings()[index]['items']
        vertices = [item[1] for item in items]
        top = sorted(vertices, key=lambda p: p.y)[:2]
        bottom = sorted(vertices, key=lambda p: p.y)[2:]
        tl, tr = sorted(top, key=lambda p: p.x)
        bl, br = sorted(bottom, key=lambda p: p.x)
        extract(name, page, [tl, bl, br, tr], inset)

    for name, page, drawing in [
        ('card_veltelini', 5, 475), ('card_barat', 5, 343),
        ('card_muscat', 5, 211), ('card_bread', 5, 743),
        ('card_spill', 5, 605), ('card_tip', 6, 115),
        ('card_break', 6, 286), ('card_shield', 6, 12),
        ('cup_2', 4, 209), ('cup_3', 4, 110), ('cup_5', 4, 11),
    ]:
        from_drawing(name, page, drawing)

    # Soda trim corners follow the rulebook's original printer crop marks.
    extract('card_soda', 5, [(249.743, 232.157), (249.433, 303.111),
                           (300.456, 303.334), (300.766, 232.38)], inset=0)
    for page, names in [
        (9, ['melyivo_fred', 'lottyintos', 'kuv_evi', 'poharnok', 'recycle_bela', 'sarki_jezus']),
        (10, ['sommelier_pityu', 'vizkopo_karesz', 'boske', 'hollosi', 'buzgomocsing', 'icuka']),
    ]:
        candidates = [(i, x) for i, x in enumerate(doc[page].get_drawings())
                      if x['fill'] and min(x['fill']) > .99
                      and 0 < x['rect'].x0 < 80 and 50 < x['rect'].width < 70
                      and 75 < x['rect'].height < 90 and len(x['items']) == 4]
        candidates.sort(key=lambda pair: pair[1]['rect'].y0)
        assert len(candidates) == 6
        for name, (index, _) in zip(names, candidates):
            from_drawing(f'hero_{name}', page, index, inset=2.2)

    pix = doc[0].get_pixmap(matrix=pymupdf.Matrix(4, 4),
                          clip=pymupdf.Rect(85, 24, 301, 77))
    logo = Image.frombytes('RGB', (pix.width, pix.height), pix.samples).convert('RGBA')
    # Remove only the connected paper outside the ribbon. The cream-coloured
    # lettering inside the ribbon must remain opaque.
    for seed in [(0, 0), (logo.width-1, 0), (0, logo.height-1),
                 (logo.width-1, logo.height-1)]:
        ImageDraw.floodfill(logo, seed, (0, 0, 0, 0), thresh=12)
    logo.save(OUT / 'logo.png', optimize=True)
    entries.append({'file': 'logo.png', 'page': 1, 'size': list(logo.size)})
    manifest = {'source': SOURCE, 'source_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
                'retrieved': '2026-11-15', 'method': 'Native PDF render, trim and straighten; no AI redraw.',
                'assets': sorted(entries, key=lambda x: x['file'])}
    (OUT / 'sources.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(f'Extracted {len(entries)} original artwork assets to {OUT}')


if __name__ == '__main__':
    main()
