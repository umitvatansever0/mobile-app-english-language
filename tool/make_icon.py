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


def flag_us(d):
    """ABD bayrağı, d x d kare (kanton görünsün diye soldan kırpılır)."""
    W, H = int(d * 1.9), d
    img = Image.new('RGB', (W, H), WHITE)
    g = ImageDraw.Draw(img)
    sh = H / 13
    for i in range(0, 13, 2):
        g.rectangle([0, i * sh, W, (i + 1) * sh], fill=(178, 34, 52))
    cw, ch = W * 0.4, sh * 7
    g.rectangle([0, 0, cw, ch], fill=(60, 59, 110))
    r = sh * 0.28
    for row in range(5):
        for col in range(6):
            x = cw * (col + 0.5 + (0.5 if row % 2 else 0)) / 6.5
            y = ch * (row + 0.5) / 5
            g.ellipse([x - r, y - r, x + r, y + r], fill=WHITE)
    x0 = int(W * 0.12)
    return img.crop((x0, 0, x0 + d, d))


def _bubble_shadow(size, box, radius, u):
    sh = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    ImageDraw.Draw(sh).rounded_rectangle([box[0], box[1] + 24 * u, box[2], box[3] + 24 * u], radius, fill=(3, 30, 40, 90))
    return sh.filter(ImageFilter.GaussianBlur(23 * u))


def foreground(size):
    """Şeffaf zeminde iki konuşma balonu (Selam / Hello) ve TR-UK-US bayrakları."""
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    u = size / 1000

    # Arka balon (sarı) "Selam"
    b1 = [150 * u, 170 * u, 640 * u, 440 * u]
    img.alpha_composite(_bubble_shadow(size, b1, 120 * u, u))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle(b1, 120 * u, fill=SUN)
    d.polygon([(250 * u, 430 * u), (330 * u, 430 * u), (220 * u, 520 * u)], fill=SUN)
    text_center(d, ((b1[0] + b1[2]) / 2, (b1[1] + b1[3]) / 2 - 6 * u), 'Selam',
                ImageFont.truetype(FONT, int(120 * u)), (120, 74, 0))

    # Ön balon (beyaz) "Hello"
    b2 = [330 * u, 430 * u, 860 * u, 720 * u]
    img.alpha_composite(_bubble_shadow(size, b2, 130 * u, u))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle(b2, 130 * u, fill=WHITE)
    d.polygon([(700 * u, 710 * u), (780 * u, 710 * u), (810 * u, 810 * u)], fill=WHITE)
    text_center(d, ((b2[0] + b2[2]) / 2, (b2[1] + b2[3]) / 2 - 6 * u), 'Hello',
                ImageFont.truetype(FONT, int(150 * u)), INK)

    # Bayraklar: TR, UK, US
    for i, fn in enumerate([flag_tr, flag_uk, flag_us]):
        flag_badge(img, ((330 + (i - 1) * 125) * u, 820 * u), 52 * u, fn, u)
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
