import sys
from PIL import Image

src, cols, out = sys.argv[1], int(sys.argv[2]), sys.argv[3]
img = Image.open(src).convert("RGBA")
w, h = img.size
cw = w / cols
ch = cw * 2
rows = int(h / ch + 0.5)
px = img.load()

DARK = "#%&8"
WHITE = "@Oo"
YELLOW = "$sS"


def cell(cx, cy):
    x0, x1 = int(cx * cw), max(int(cx * cw) + 1, int((cx + 1) * cw))
    y0, y1 = int(cy * ch), max(int(cy * ch) + 1, min(h, int((cy + 1) * ch)))
    n = a = r = g = b = 0
    for y in range(y0, min(y1, h)):
        for x in range(x0, min(x1, w)):
            pr, pg, pb, pa = px[x, y]
            n += 1
            a += pa
            r += pr * pa
            g += pg * pa
            b += pb * pa
    if not n or not a:
        return None
    return a / n / 255, r / a, g / a, b / a


lines = []
for cy in range(rows):
    line = ""
    last = None
    for cx in range(cols):
        c = cell(cx, cy)
        if c is None or c[0] < 0.2:
            line += " "
            continue
        cov, r, g, b = c
        lum = 0.3 * r + 0.59 * g + 0.11 * b
        sat = max(r, g, b) - min(r, g, b)
        if cov < 0.55:
            ch_ = "."
        elif sat > 60 and r > 150:
            ch_ = YELLOW[min(len(YELLOW) - 1, int((255 - lum) / 90 * len(YELLOW)))]
        elif lum > 150:
            ch_ = WHITE[min(len(WHITE) - 1, int((255 - lum) / 106 * len(WHITE)))]
        else:
            ch_ = DARK[min(len(DARK) - 1, int(lum / 150 * len(DARK)))]
        if sat > 60 and r > 150:
            col = (int(r), int(g * 0.95), int(b * 0.6))
        elif lum > 150:
            col = (int(min(255, r + 10)), int(min(255, g + 10)), int(min(255, b + 10)))
        else:
            k = 0.4 + 0.6 * min(1.0, lum / 120)
            col = (int(80 + 80 * k), int(94 + 86 * k), int(116 + 90 * k))
        if col != last:
            line += "\x1b[38;2;%d;%d;%dm" % col
            last = col
        line += ch_
    lines.append(line + "\x1b[0m")
while lines and not lines[0].replace("\x1b[0m", "").strip():
    lines.pop(0)
while lines and not lines[-1].replace("\x1b[0m", "").strip():
    lines.pop()
open(out, "w").write("\n".join(lines) + "\n")
