#!/usr/bin/env python3
"""Print-ready cartridge label art for Pixel Racer NES (original artwork).

Draws the front label (sunset city, neon road, the hero coupe, the logo) and
an end label at high resolution with bleed, plus guide versions showing the
trim and safe-area lines.

    python3 tools/mklabel.py                       # default sizes, 600 dpi
    python3 tools/mklabel.py --front 63.5x56 --end 50x12 --bleed 2 --dpi 600

Sizes are in millimetres, width x height, at the trim line.  Label stickers
differ between shells and reproduction carts: measure yours (or use your
label printer's template) and pass the sizes.  Keep everything important
inside the safe area (3 mm inside the trim).

Writes <name>.png and <name>.pdf (art with bleed) and <name>_guides.png.
Needs Pillow and the Inter font (fonts-inter; SIL Open Font License).
"""
import argparse
import math
import os
import random

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

FONT = '/usr/share/fonts/opentype/inter/InterDisplay-BoldItalic.otf'
FONT_BOLD = '/usr/share/fonts/opentype/inter/Inter-ExtraBold.otf'
SS = 2                                    # supersampling for smooth edges
SAFE_MM = 3.0


def mm2px(mm, dpi):
    return int(round(mm / 25.4 * dpi))


def lerp(a, b, t):
    return tuple(int(round(x + (y - x) * t)) for x, y in zip(a, b))


def vgradient(w, h, stops):
    """stops: [(t, rgb), ...] top to bottom."""
    img = Image.new('RGB', (1, h))
    px = img.load()
    for y in range(h):
        t = y / max(1, h - 1)
        for (t0, c0), (t1, c1) in zip(stops, stops[1:]):
            if t0 <= t <= t1:
                px[0, y] = lerp(c0, c1, (t - t0) / max(1e-9, t1 - t0))
                break
    return img.resize((w, h))


def hex2(c):
    return tuple(int(c[i:i + 2], 16) for i in (1, 3, 5))


# --------------------------------------------------------------------------
# Scene pieces (all coordinates in pixels of the full canvas incl. bleed)
# --------------------------------------------------------------------------
def draw_sky(img, horizon):
    w, h = img.size
    sky = vgradient(w, horizon, [(0, hex2('#120634')), (0.45, hex2('#4a1170')),
                                 (0.78, hex2('#c42a6a')), (1, hex2('#ff8a3d'))])
    img.paste(sky, (0, 0))
    d = ImageDraw.Draw(img)
    rnd = random.Random(7)
    for _ in range(int(w * h / 9000)):                    # stars
        x, y = rnd.random() * w, rnd.random() * horizon * 0.55
        r = rnd.choice([1, 1, 1, 2, 2, 3]) * w / 2400
        a = rnd.randint(150, 255)
        d.ellipse([x - r, y - r, x + r, y + r], fill=(a, a, 255))


def draw_sun(img, cx, horizon, r):
    w, h = img.size
    sun = vgradient(int(2 * r), int(2 * r), [(0, hex2('#fff27a')), (0.5, hex2('#ffb43d')),
                                             (1, hex2('#ff3d7f'))])
    mask = Image.new('L', sun.size, 0)
    md = ImageDraw.Draw(mask)
    md.ellipse([0, 0, 2 * r - 1, 2 * r - 1], fill=255)
    # retro stripes cut into the lower half, thicker toward the horizon
    y, gap = r * 1.0, r * 0.035
    while y < 2 * r:
        md.rectangle([0, y, 2 * r, y + gap], fill=0)
        y += gap * 2.6
        gap *= 1.28
    glow = Image.new('RGB', img.size, (0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.ellipse([cx - r * 1.35, horizon - r * 1.6 - r * 0.35, cx + r * 1.35, horizon + r * 1.1],
               fill=(255, 90, 120))
    glow = glow.filter(ImageFilter.GaussianBlur(r * 0.35))
    img.paste(ImageChops.screen(img, glow), (0, 0))
    top = int(horizon - r * 1.45)
    img.paste(sun, (int(cx - r), top), mask)


def draw_city(img, horizon, seed, color, hmin, hmax, windows):
    w, h = img.size
    d = ImageDraw.Draw(img)
    rnd = random.Random(seed)
    x = -w * 0.02
    while x < w * 1.02:
        bw = rnd.uniform(0.035, 0.09) * w
        bh = rnd.uniform(hmin, hmax) * h
        top = horizon - bh
        d.rectangle([x, top, x + bw, horizon], fill=color)
        if rnd.random() < 0.25:                            # antenna
            ax = x + bw * rnd.uniform(0.3, 0.7)
            d.rectangle([ax, top - bh * 0.18, ax + w * 0.002, top], fill=color)
        if windows:
            ws, gx, gy = w * 0.0055, w * 0.012, w * 0.016
            yy = top + gy * 0.8
            while yy < horizon - gy * 0.6:
                xx = x + gx * 0.6
                while xx < x + bw - gx * 0.6:
                    if rnd.random() < 0.38:
                        c = rnd.choice([(255, 214, 120), (255, 236, 170), (120, 230, 255)])
                        d.rectangle([xx, yy, xx + ws, yy + ws * 1.4], fill=c)
                    xx += gx
                yy += gy
        x += bw + rnd.uniform(0, 0.012) * w


def draw_road(img, horizon):
    w, h = img.size
    ground = vgradient(w, h - horizon, [(0, hex2('#2a0c3e')), (1, hex2('#07030f'))])
    img.paste(ground, (0, horizon))
    lines = Image.new('RGB', img.size, (0, 0, 0))
    d = ImageDraw.Draw(lines)
    vx = w / 2
    lw = max(2, int(w / 500))
    for i in range(-14, 15):                               # perspective lines
        d.line([(vx, horizon), (vx + i * w * 0.16, h * 1.05)], fill=(255, 60, 200), width=lw)
    t = 0.02
    while True:                                            # horizontal lines
        y = horizon + (h - horizon) * t
        if y > h:
            break
        d.line([(0, y), (w, y)], fill=(255, 60, 200), width=lw)
        t *= 1.55
    d.line([(0, horizon), (w, horizon)], fill=(255, 170, 230), width=lw * 2)
    soft = lines.filter(ImageFilter.GaussianBlur(w / 300))
    img.paste(ImageChops.screen(img, ImageChops.screen(lines, soft)), (0, 0))


def draw_car(img, cx, base, length, body=(214, 32, 46)):
    """Original 90s-style sports coupe, side view, facing right.  cx = centre,
    base = ground line, length = bumper to bumper."""
    L = length
    def P(u, v):                                           # u along, v up (in L units)
        return (cx + (u - 0.5) * L, base - v * L)
    d = ImageDraw.Draw(img)
    w, h = img.size
    # shadow
    sh = Image.new('L', img.size, 0)
    ImageDraw.Draw(sh).ellipse([*P(0.02, 0.035), *P(0.98, -0.03)], fill=200)
    sh = sh.filter(ImageFilter.GaussianBlur(L * 0.02))
    img.paste((5, 0, 12), (0, 0), sh)
    # speed streaks behind
    for i, (v, ln) in enumerate(((0.08, 0.45), (0.15, 0.3), (0.22, 0.38), (0.12, 0.22))):
        y = P(0, v)[1]
        x0 = P(-ln, 0)[0]
        d.line([(x0, y), (P(-0.02, 0)[0], y)], fill=(255, 200, 240), width=max(2, int(L / 260)))
    dark = tuple(int(c * 0.55) for c in body)
    light = tuple(min(255, int(c * 1.35 + 30)) for c in body)
    # lower body
    lower = [P(0.0, 0.07), P(0.02, 0.14), P(0.2, 0.17), P(0.62, 0.175), P(0.9, 0.16),
             P(1.0, 0.13), P(1.01, 0.08), P(0.97, 0.05), P(0.03, 0.05)]
    d.polygon(lower, fill=body)
    # cabin
    cabin = [P(0.22, 0.17), P(0.36, 0.265), P(0.5, 0.28), P(0.63, 0.27), P(0.76, 0.18)]
    d.polygon(cabin, fill=body)
    # glass with a gradient
    gl = [P(0.27, 0.175), P(0.375, 0.252), P(0.5, 0.264), P(0.6, 0.254), P(0.7, 0.18)]
    gmask = Image.new('L', img.size, 0)
    ImageDraw.Draw(gmask).polygon(gl, fill=255)
    bbox = gmask.getbbox()
    gimg = vgradient(bbox[2] - bbox[0], bbox[3] - bbox[1], [(0, hex2('#a8e6ff')), (1, hex2('#2a3f8f'))])
    img.paste(gimg, bbox[:2], gmask.crop(bbox))
    d.line([P(0.49, 0.262), P(0.5, 0.176)], fill=dark, width=max(3, int(L / 120)))   # B-pillar
    # body shading and highlight
    d.polygon([P(0.03, 0.05), P(0.97, 0.05), P(1.01, 0.08), P(0.0, 0.08)], fill=dark)
    d.line([P(0.05, 0.135), P(0.6, 0.155), P(0.95, 0.14)], fill=light, width=max(3, int(L / 140)))
    d.line([P(0.2, 0.17), P(0.62, 0.175)], fill=light, width=max(2, int(L / 220)))
    # rear spoiler
    d.polygon([P(0.0, 0.165), P(0.12, 0.17), P(0.12, 0.185), P(-0.01, 0.19)], fill=dark)
    d.rectangle([*P(0.05, 0.185), *P(0.065, 0.165)], fill=dark)
    # lights
    d.polygon([P(0.97, 0.13), P(1.0, 0.125), P(1.005, 0.105), P(0.96, 0.11)], fill=(255, 250, 210))
    d.polygon([P(0.005, 0.13), P(0.04, 0.135), P(0.04, 0.115), P(0.0, 0.11)], fill=(255, 40, 60))
    glow = Image.new('RGB', img.size, (0, 0, 0))
    gd = ImageDraw.Draw(glow)
    hx, hy = P(1.0, 0.115)
    gd.polygon([(hx, hy - L * 0.01), (hx + L * 0.45, hy - L * 0.08), (hx + L * 0.45, hy + L * 0.07),
                (hx, hy + L * 0.012)], fill=(150, 140, 90))
    glow = glow.filter(ImageFilter.GaussianBlur(L * 0.03))
    img.paste(ImageChops.screen(img, glow), (0, 0))
    d = ImageDraw.Draw(img)
    # wheels: arches, tyres, chrome rims with spokes
    for u in (0.19, 0.8):
        wx, wy = P(u, 0.075)
        r = L * 0.085
        d.ellipse([wx - r * 1.12, wy - r * 1.12, wx + r * 1.12, wy + r * 1.12], fill=(10, 4, 16))
        d.ellipse([wx - r, wy - r, wx + r, wy + r], fill=(18, 18, 22))
        rr = r * 0.62
        rim = vgradient(int(2 * rr), int(2 * rr), [(0, hex2('#f4f6ff')), (0.5, hex2('#9aa3b8')),
                                                   (1, hex2('#e6e9f5'))])
        m = Image.new('L', rim.size, 0)
        ImageDraw.Draw(m).ellipse([0, 0, 2 * rr - 1, 2 * rr - 1], fill=255)
        img.paste(rim, (int(wx - rr), int(wy - rr)), m)
        for k in range(5):
            a = k * 2 * math.pi / 5
            d.line([(wx, wy), (wx + math.cos(a) * rr * 0.92, wy + math.sin(a) * rr * 0.92)],
                   fill=(70, 74, 90), width=max(3, int(L / 110)))
        d.ellipse([wx - rr * 0.22, wy - rr * 0.22, wx + rr * 0.22, wy + rr * 0.22], fill=(40, 42, 54))


def text_layer(size, text, font, fill_stops, stroke, stroke_rgb, glow_rgb, pos, anchor='ms'):
    """Gradient-filled text with an outline and a glow, as an RGBA layer."""
    w, h = size
    mask = Image.new('L', size, 0)
    ImageDraw.Draw(mask).text(pos, text, font=font, fill=255, anchor=anchor)
    smask = Image.new('L', size, 0)
    ImageDraw.Draw(smask).text(pos, text, font=font, fill=255, anchor=anchor,
                               stroke_width=stroke, stroke_fill=255)
    bbox = smask.getbbox()
    layer = Image.new('RGBA', size, (0, 0, 0, 0))
    if glow_rgb:
        g = smask.filter(ImageFilter.GaussianBlur(stroke * 2.2))
        layer.paste(Image.new('RGBA', size, glow_rgb + (255,)), (0, 0), g)
    layer.paste(Image.new('RGBA', size, stroke_rgb + (255,)), (0, 0), smask)
    grad = vgradient(bbox[2] - bbox[0], bbox[3] - bbox[1], fill_stops).convert('RGBA')
    full = Image.new('RGBA', size, (0, 0, 0, 0))
    full.paste(grad, bbox[:2])
    layer.paste(full, (0, 0), mask)
    return layer


CHROME = [(0, hex2('#ffffff')), (0.45, hex2('#bfe9ff')), (0.5, hex2('#3a4f9a')),
          (0.62, hex2('#ff9ad5')), (1, hex2('#fff1a8'))]


# --------------------------------------------------------------------------
def front(w, h, bleed, safe):
    img = Image.new('RGB', (w, h))
    horizon = int(h * 0.66)
    draw_sky(img, horizon)
    draw_sun(img, w * 0.5, horizon, w * 0.24)
    draw_city(img, horizon, 3, (58, 20, 86), 0.08, 0.22, False)
    draw_city(img, horizon, 9, (16, 6, 30), 0.05, 0.15, True)
    draw_road(img, horizon)
    draw_car(img, w * 0.5, h * 0.855, w * 0.7)
    img = img.convert('RGBA')
    # logo
    f1 = ImageFont.truetype(FONT, int(h * 0.165))
    img.alpha_composite(text_layer(img.size, 'PIXEL', f1, CHROME, int(h * 0.012), (24, 6, 48),
                                   (255, 60, 180), (w * 0.5, safe + h * 0.155)))
    img.alpha_composite(text_layer(img.size, 'RACER', f1, CHROME, int(h * 0.012), (24, 6, 48),
                                   (255, 60, 180), (w * 0.5, safe + h * 0.3)))
    # NES EDITION ribbon
    rf = ImageFont.truetype(FONT_BOLD, int(h * 0.042))
    rd = ImageDraw.Draw(img)
    ry = safe + h * 0.355
    tw = rd.textlength('NES EDITION', font=rf)
    pad = h * 0.02
    rd.polygon([(w / 2 - tw / 2 - pad * 1.6, ry), (w / 2 + tw / 2 + pad * 2.2, ry),
                (w / 2 + tw / 2 + pad * 1.6, ry + h * 0.058), (w / 2 - tw / 2 - pad * 2.2, ry + h * 0.058)],
               fill=(18, 220, 235))
    rd.text((w / 2, ry + h * 0.029), 'NES EDITION', font=rf, fill=(20, 6, 40), anchor='mm')
    # footer: dark band from the bottom bleed up past the text, text inside the safe area
    msg = 'UNOFFICIAL FAN-MADE DEMAKE  •  ORIGINAL ART AND MUSIC'
    ff = fit_font(FONT_BOLD, msg, (w - 2 * safe) * 0.88, h * 0.026)
    top = h - safe - h * 0.045
    band = vgradient(w, int(h - top), [(0, (10, 4, 22)), (1, (10, 4, 22))]).convert('RGBA')
    band.putalpha(vgradient(w, int(h - top), [(0, (0, 0, 0)), (0.35, (200,) * 3), (1, (235,) * 3)]).convert('L'))
    img.alpha_composite(band, (0, int(top)))
    rd = ImageDraw.Draw(img)
    rd.text((w / 2, h - safe - h * 0.008), msg, font=ff, fill=(255, 230, 250), anchor='ms')
    return img.convert('RGB')


def end(w, h, bleed, safe):
    img = vgradient(w, h, [(0, hex2('#2a0c4e')), (0.55, hex2('#c42a6a')), (1, hex2('#ff8a3d'))]).convert('RGBA')
    stroke = max(2, int((h - 2 * safe) * 0.07))
    f = fit_font(FONT, 'PIXEL RACER', w - 2 * safe - 2 * stroke, h - 2 * safe - 2 * stroke)
    img.alpha_composite(text_layer(img.size, 'PIXEL RACER', f, CHROME, stroke,
                                   (24, 6, 48), (255, 60, 180), (w / 2, h * 0.5), anchor='mm'))
    return img.convert('RGB')


def fit_font(path, text, maxw, maxh):
    """Largest size of the font whose ink box for text fits maxw x maxh."""
    size = int(maxh * 2)
    while size > 4:
        f = ImageFont.truetype(path, size)
        x0, y0, x1, y1 = f.getbbox(text)
        if x1 - x0 <= maxw and y1 - y0 <= maxh:
            return f
        size = int(size * 0.96)
    return ImageFont.truetype(path, 4)


def guides(img, dpi, bleed):
    g = img.copy()
    d = ImageDraw.Draw(g)
    w, h = g.size
    s = mm2px(SAFE_MM, dpi) + bleed
    lw = max(2, dpi // 150)
    d.rectangle([bleed, bleed, w - bleed - 1, h - bleed - 1], outline=(0, 255, 0), width=lw)   # trim
    d.rectangle([s, s, w - s - 1, h - s - 1], outline=(0, 160, 255), width=lw)                   # safe
    return g


def render(fn, wmm, hmm, bleed_mm, dpi):
    bleed = mm2px(bleed_mm, dpi)
    w, h = mm2px(wmm, dpi) + 2 * bleed, mm2px(hmm, dpi) + 2 * bleed
    big = fn(w * SS, h * SS, bleed * SS, (bleed + mm2px(SAFE_MM, dpi)) * SS)
    return big.resize((w, h), Image.LANCZOS), bleed


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--front', default='63.5x56', help='front label trim size, mm (WxH)')
    ap.add_argument('--end', default='50x12', help='end label trim size, mm (WxH)')
    ap.add_argument('--bleed', type=float, default=2.0, help='bleed on every side, mm')
    ap.add_argument('--dpi', type=int, default=600)
    ap.add_argument('--out', default='art/label')
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    for name, fn, size in (('front', front, a.front), ('end', end, a.end)):
        wmm, hmm = (float(x) for x in size.lower().split('x'))
        img, bleed = render(fn, wmm, hmm, a.bleed, a.dpi)
        base = os.path.join(a.out, name)
        img.save(base + '.png', dpi=(a.dpi, a.dpi))
        img.save(base + '.pdf', resolution=a.dpi)        # exact physical size, for print shops
        guides(img, a.dpi, bleed).save(base + '_guides.png', dpi=(a.dpi, a.dpi))
        print('%s: %s mm + %.1f mm bleed -> %dx%d px at %d dpi' % (name, size, a.bleed,
                                                                 img.size[0], img.size[1], a.dpi))


if __name__ == '__main__':
    main()
