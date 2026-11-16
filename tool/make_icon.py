"""İngilizce Kartlar uygulama ikonu üretici.

Kullanım (proje kökünden): python tool/make_icon.py . <önizleme_klasörü>
"""
import math
import os
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageChops

ROOT = sys.argv[1]
PREVIEW = sys.argv[2]
FONT = os.path.join(ROOT, 'assets', 'fonts', 'Nunito_900Black.ttf')

S = 2048  # çalışma çözünürlüğü

TEAL_LIGHT = (32, 201, 180)
TEAL = (14, 159, 148)
TEAL_DEEP = (8, 92, 90)
INK = (11, 90, 86)
SUN = (255, 200, 69)
SUN_DEEP = (238, 164, 18)
ROSE = (240, 82, 96)
WHITE = (255, 255, 255)
CARD_EDGE = (196, 232, 226)


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def background(size):
    """Sol üstten sağ alta turkuaz degrade + üstte yumuşak ışık."""
    small = 256
    g = Image.new('RGB', (small, small))
    px = g.load()
    for y in range(small):
        for x in range(small):
            t = (x + y) / (2 * (small - 1))
            c = lerp(TEAL_LIGHT, TEAL, min(1, t * 1.4)) if t < 0.7 else lerp(TEAL, TEAL_DEEP, (t - 0.7) / 0.3 * 0.8)
            px[x, y] = c
    g = g.resize((size, size), Image.BICUBIC)
    # Işık halesi
    glow = Image.new('L', (size, size), 0)
    d = ImageDraw.Draw(glow)
    r = size * 0.55
    cx, cy = size * 0.32, size * 0.25
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=70)
    glow = glow.filter(ImageFilter.GaussianBlur(size * 0.12))
    g = Image.composite(Image.new('RGB', (size, size), WHITE), g, glow)
    return g


def rounded_card(w, h, radius, fill, edge=None, edge_h=0):
    """Yuvarlak köşeli kart; isteğe bağlı alt kenar kalınlığı (kart yığını hissi)."""
    img = Image.new('RGBA', (w, h + edge_h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    if edge:
        d.rounded_rectangle([0, edge_h, w - 1, h + edge_h - 1], radius, fill=edge)
    d.rounded_rectangle([0, 0, w - 1, h - 1], radius, fill=fill)
    return img


def paste_rotated(base, layer, center, angle, shadow=True):
    pad = int(base.width * 0.08)
    padded = Image.new('RGBA', (layer.width + 2 * pad, layer.height + 2 * pad), (0, 0, 0, 0))
    padded.alpha_composite(layer, (pad, pad))
    rot = padded.rotate(angle, resample=Image.BICUBIC, expand=True)
    x = int(center[0] - rot.width / 2)
    y = int(center[1] - rot.height / 2)
    if shadow:
        a = rot.split()[3]
        sh = Image.new('RGBA', rot.size, (4, 50, 48, 0))
        sh.putalpha(a.point(lambda v: int(v * 0.38)))
        sh = sh.filter(ImageFilter.GaussianBlur(base.width * 0.022))
        base.alpha_composite(sh, (x + int(base.width * 0.012), y + int(base.width * 0.03)))
    base.alpha_composite(rot, (x, y))


def text_center(d, box_center, txt, font, fill):
    l, t, r, b = d.textbbox((0, 0), txt, font=font)
    d.text((box_center[0] - (l + r) / 2, box_center[1] - (t + b) / 2), txt, font=font, fill=fill)


def _star(cx, cy, r_out, r_in, rot_deg=0):
    pts = []
    for i in range(10):
        r = r_out if i % 2 == 0 else r_in
        a = math.radians(rot_deg + i * 36)
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def flag_tr(d):
    """Türk bayrağı, d x d kare (daireye kırpılacak). Hilal + yıldız ortalanmış."""
    img = Image.new('RGB', (d, d), (227, 10, 23))
    g = ImageDraw.Draw(img)
    h = d * 0.95  # bayrak yüksekliği ölçeği
    ox = d * 0.5 - h * 0.13  # hilal+yıldız grubunu ortala
    oy = d * 0.5
    r1, r2 = h * 0.25, h * 0.20
    g.ellipse([ox - r1, oy - r1, ox + r1, oy + r1], fill=WHITE)
    c2 = ox + h * 0.0625
    g.ellipse([c2 - r2, oy - r2, c2 + r2, oy + r2], fill=(227, 10, 23))
    sx = c2 + r2 + h * 0.03 + h * 0.125 * 0.6
    g.polygon(_star(sx, oy, h * 0.125, h * 0.125 * 0.382, 180), fill=WHITE)
    return img


def flag_uk(d):
    """Birleşik Krallık bayrağı (Union Jack), d x d kare."""
    W, H = d * 2, d  # 2:1 bayrak, ortası kırpılacak
    img = Image.new('RGB', (W, H), (1, 33, 105))
    g = ImageDraw.Draw(img)
    u = H / 30
    g.line([(0, 0), (W, H)], fill=WHITE, width=int(6 * u))
    g.line([(0, H), (W, 0)], fill=WHITE, width=int(6 * u))
    g.line([(0, 0), (W, H)], fill=(200, 16, 46), width=int(2 * u))
    g.line([(0, H), (W, 0)], fill=(200, 16, 46), width=int(2 * u))
    g.rectangle([W / 2 - 5 * u, 0, W / 2 + 5 * u, H], fill=WHITE)
    g.rectangle([0, H / 2 - 5 * u, W, H / 2 + 5 * u], fill=WHITE)
    g.rectangle([W / 2 - 3 * u, 0, W / 2 + 3 * u, H], fill=(200, 16, 46))
    g.rectangle([0, H / 2 - 3 * u, W, H / 2 + 3 * u], fill=(200, 16, 46))
    return img.crop((int(W / 2 - d / 2), 0, int(W / 2 + d / 2), d))


def flag_badge(img, center, r, flag_fn, u):
    """Beyaz çerçeveli, gölgeli yuvarlak bayrak rozeti."""
    size = img.width
    sh = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    ImageDraw.Draw(sh).ellipse([center[0] - r, center[1] - r + 8 * u, center[0] + r, center[1] + r + 8 * u],
                               fill=(4, 50, 48, 80))
    img.alpha_composite(sh.filter(ImageFilter.GaussianBlur(10 * u)))
    d = ImageDraw.Draw(img)
    ring = 10 * u
    d.ellipse([center[0] - r - ring, center[1] - r - ring, center[0] + r + ring, center[1] + r + ring], fill=WHITE)
    dd = int(2 * r)
    f = flag_fn(dd).convert('RGBA')
    m = Image.new('L', (dd, dd), 0)
    ImageDraw.Draw(m).ellipse([0, 0, dd - 1, dd - 1], fill=255)
    f.putalpha(m)
    img.alpha_composite(f, (int(center[0] - r), int(center[1] - r)))


def foreground(size):
    """Şeffaf zeminde kart yığını + ses rozeti. İçerik merkez ~%62 alanda kalır."""
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    u = size / 1000  # birim

    cw, ch = int(400 * u), int(520 * u)
    rad = int(64 * u)

    # Arka kart (sarı) — "TR" tarafı
    back = rounded_card(cw, ch, rad, SUN, SUN_DEEP, int(16 * u))
    bd = ImageDraw.Draw(back)
    # Arka kartta sadece yumuşak "satır" çizgileri (görünen sol kenarda)
    for i in range(3):
        y = ch * (0.30 + i * 0.16)
        bd.rounded_rectangle([cw * 0.10, y, cw * 0.36, y + 30 * u], int(15 * u), fill=(244, 182, 40))
    paste_rotated(img, back, (size * 0.415, size * 0.5), 13)

    # Ön kart (beyaz) — "Ab" ve altında çizgi
    front = rounded_card(cw, ch, rad, WHITE, CARD_EDGE, int(22 * u))
    fd = ImageDraw.Draw(front)
    f_big = ImageFont.truetype(FONT, int(225 * u))
    text_center(fd, (cw * 0.5, ch * 0.43), 'Ab', f_big, INK)
    y = ch * 0.74
    fd.rounded_rectangle([cw * 0.26, y, cw * 0.74, y + 40 * u], int(20 * u), fill=TEAL)
    paste_rotated(img, front, (size * 0.545, size * 0.505), -7)

    # Ses rozeti (telaffuz) — sağ üst
    bc = (size * 0.735, size * 0.30)
    br = 92 * u
    badge = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    bdr = ImageDraw.Draw(badge)
    bdr.ellipse([bc[0] - br, bc[1] - br + 10 * u, bc[0] + br, bc[1] + br + 10 * u], fill=(4, 50, 48, 90))
    badge = badge.filter(ImageFilter.GaussianBlur(14 * u))
    img.alpha_composite(badge)
    d = ImageDraw.Draw(img)
    d.ellipse([bc[0] - br - 12 * u, bc[1] - br - 12 * u, bc[0] + br + 12 * u, bc[1] + br + 12 * u], fill=WHITE)
    d.ellipse([bc[0] - br, bc[1] - br, bc[0] + br, bc[1] + br], fill=ROSE)
    # Hoparlör
    sx, sy = bc[0] - 44 * u, bc[1]
    d.rounded_rectangle([sx - 18 * u, sy - 20 * u, sx + 6 * u, sy + 20 * u], int(6 * u), fill=WHITE)
    d.polygon([(sx, sy - 20 * u), (sx + 34 * u, sy - 46 * u), (sx + 34 * u, sy + 46 * u), (sx, sy + 20 * u)], fill=WHITE)
    # Ses dalgaları
    for i, rr in enumerate([30, 56]):
        r_ = rr * u
        ox = sx + 40 * u
        d.arc([ox - r_, sy - r_, ox + r_, sy + r_], -50, 50, fill=WHITE, width=int(13 * u))
    # Küçük bayrak rozetleri: TR (sarı kart, sol alt) ve UK (beyaz kart, sağ alt)
    flag_badge(img, (size * 0.305, size * 0.735), 58 * u, flag_tr, u)
    flag_badge(img, (size * 0.715, size * 0.745), 58 * u, flag_uk, u)
    return img


def full_icon(size, circle=False):
    bg = background(size).convert('RGBA')
    fg = foreground(size)
    bg.alpha_composite(fg)
    if circle:
        m = Image.new('L', (size, size), 0)
        ImageDraw.Draw(m).ellipse([0, 0, size - 1, size - 1], fill=255)
        bg.putalpha(m)
    return bg


def adaptive_foreground(size):
    # 108dp tuval, güvenli alan 66dp (~%61). İçerik 1000 birimde ~%80'lik alana yayılıyor,
    # bu yüzden ~%74 ölçekle ortala.
    canvas = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    inner = int(size * 0.84)
    fg = foreground(S).resize((inner, inner), Image.LANCZOS)
    off = (size - inner) // 2
    canvas.alpha_composite(fg, (off, off))
    return canvas


def save(img, path, size, rgb=False):
    out = img.resize((size, size), Image.LANCZOS)
    if rgb:
        out = out.convert('RGB')
    os.makedirs(os.path.dirname(path), exist_ok=True)
    out.save(path, optimize=True)


def main():
    master = full_icon(S)
    master_round = full_icon(S, circle=True)
    fg = adaptive_foreground(S)
    bg = background(S)

    res = os.path.join(ROOT, 'android', 'app', 'src', 'main', 'res')
    dens = {'mdpi': 1, 'hdpi': 1.5, 'xhdpi': 2, 'xxhdpi': 3, 'xxxhdpi': 4}
    for name, k in dens.items():
        dpath = os.path.join(res, f'mipmap-{name}')
        save(master, os.path.join(dpath, 'ic_launcher.png'), int(48 * k))
        save(master_round, os.path.join(dpath, 'ic_launcher_round.png'), int(48 * k))
        save(fg, os.path.join(dpath, 'ic_launcher_foreground.png'), int(108 * k))
        save(bg, os.path.join(dpath, 'ic_launcher_background.png'), int(108 * k), rgb=True)

    ios = os.path.join(ROOT, 'ios', 'Runner', 'Assets.xcassets', 'AppIcon.appiconset')
    for fn in os.listdir(ios):
        if not fn.endswith('.png'):
            continue
        base = fn[len('Icon-App-'):-len('.png')]  # 20x20@2x
        pt, scale = base.split('@')
        px = round(float(pt.split('x')[0]) * int(scale.rstrip('x')))
        save(master, os.path.join(ios, fn), px, rgb=True)

    os.makedirs(PREVIEW, exist_ok=True)
    save(master, os.path.join(PREVIEW, 'icon_1024.png'), 1024, rgb=True)
    # Android maskeli önizleme (daire + squircle) yan yana
    prev = Image.new('RGB', (1100, 540), (243, 250, 248))
    ad = bg.convert('RGBA')
    ad.alpha_composite(fg)
    for i, shape in enumerate(['circle', 'rounded']):
        t = ad.resize((480, 480), Image.LANCZOS)
        m = Image.new('L', (480, 480), 0)
        md = ImageDraw.Draw(m)
        if shape == 'circle':
            md.ellipse([0, 0, 479, 479], fill=255)
        else:
            md.rounded_rectangle([0, 0, 479, 479], 110, fill=255)
        prev.paste(t, (40 + i * 540, 30), m)
    prev.save(os.path.join(PREVIEW, 'android_preview.png'))


if __name__ == '__main__':
    main()
