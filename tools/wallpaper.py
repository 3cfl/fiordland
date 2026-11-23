import math
import random
import sys

from PIL import Image, ImageDraw, ImageFilter

W, H = 3840, 2160
out = sys.argv[1] if len(sys.argv) > 1 else "wallpaper.png"
random.seed(44)


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def gradient(top, mid, bottom, split):
    img = Image.new("RGB", (W, H))
    d = ImageDraw.Draw(img)
    for y in range(H):
        t = y / H
        c = lerp(top, mid, t / split) if t < split else lerp(mid, bottom, (t - split) / (1 - split))
        d.line([(0, y), (W, y)], fill=c)
    return img


def ridge(base, amp, rough, seed, gap):
    rnd = random.Random(seed)
    pts = []
    octaves = [(rnd.uniform(0, 6.28), f, a) for f, a in ((2.0, 0.5), (5.3, 0.3), (12.1, 0.14), (29.0, 0.06))]
    for x in range(0, W + 4, 4):
        u = x / W
        n = sum((1 - abs(math.sin(u * f * math.pi + p))) * a for p, f, a in octaves)
        n += sum(math.sin(u * f * 7.3 + p * 3) * a * rough * 0.3 for p, f, a in octaves[2:])
        side = min(1.0, abs(u - 0.6) / gap) ** 1.6
        pts.append((x, base - (0.25 + 1.3 * side) * amp * (0.55 + n)))
    return pts


horizon = int(H * 0.64)
img = gradient((14, 22, 38), (46, 66, 92), (232, 178, 92), 0.55)

glow = Image.new("L", (W, H), 0)
gd = ImageDraw.Draw(glow)
cx, cy = int(W * 0.6), int(horizon - H * 0.01)
for r in range(900, 0, -12):
    gd.ellipse([cx - r * 1.6, cy - r, cx + r * 1.6, cy + r], fill=int(255 * (1 - r / 900) ** 2.2))
glow = glow.filter(ImageFilter.GaussianBlur(60))
img = Image.composite(Image.new("RGB", (W, H), (255, 176, 48)), img, glow.point(lambda v: v * 0.8))

layers = [
    (horizon - 40, 260, 0.6, (88, 96, 118), 1, 0.25),
    (horizon - 10, 380, 0.8, (52, 62, 84), 2, 0.38),
    (horizon, 520, 1.0, (28, 36, 54), 3, 0.5),
    (horizon, 700, 1.2, (11, 16, 27), 4, 0.62),
]
for base, amp, rough, col, seed, gap in layers:
    mask = Image.new("L", (W, H), 0)
    pts = ridge(base, amp, rough, seed, gap) + [(W, horizon), (0, horizon)]
    ImageDraw.Draw(mask).polygon(pts, fill=255)
    img.paste(Image.new("RGB", (W, H), col), (0, 0), mask)
    mist = Image.new("L", (W, H), 0)
    ImageDraw.Draw(mist).rectangle([0, base - 120, W, horizon], fill=55)
    mist = mist.filter(ImageFilter.GaussianBlur(90))
    img = Image.composite(Image.new("RGB", (W, H), (150, 165, 185)), img, mist)

sky = img.crop((0, 0, W, horizon))
refl = sky.transpose(Image.FLIP_TOP_BOTTOM).resize((W, H - horizon))
refl = refl.filter(ImageFilter.GaussianBlur(6))
water = Image.new("RGB", (W, H - horizon), (10, 16, 28))
fade = Image.linear_gradient("L").resize((W, H - horizon)).point(lambda v: 90 + v * 0.55)
refl = Image.composite(water, refl, fade)
d = ImageDraw.Draw(refl)
for _ in range(900):
    y = int(random.random() ** 1.8 * (H - horizon))
    x = random.randint(0, W)
    w = random.randint(40, 260) * (1 + y / 300)
    c = refl.getpixel((min(x, W - 1), min(y, H - horizon - 1)))
    d.line([(x, y), (x + w, y)], fill=tuple(min(255, v + 18) for v in c), width=2)
img.paste(refl, (0, horizon))

vign = Image.radial_gradient("L").resize((W, H)).point(lambda v: int(v * 0.42))
img = Image.composite(Image.new("RGB", (W, H), (6, 9, 16)), img, vign)
img.save(out, optimize=True)
