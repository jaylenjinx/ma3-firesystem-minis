#!/usr/bin/env python3
"""Draws the mini tools' own icons: the buttons FireSystem has no icon for (Fade, Delay, Wings,
Blocks, Steps, Part, Master, the Position Picker's extra tilts, FX sizes, the LOS bumps ...).

The list (name, style, colour family) is MINI in src/FSIcons.lua; its order gives each icon its
image and appearance slots there, so keep the two in step by only ever reading it from there.

  icons/mini/fs_mi_<name>.png         white glyph on transparent (the "Keep colour and text" look)
  icons/mini/fs_r_mi_<name>_<s>.png   the glyph on a disc in FireSystem's round style, s = i / o / p:
                                      i idle (dark disc), o on, p pending (bright disc, white ring)

Style "full": the glyph fills the disc like FireSystem's (o = white disc, glyph in the family colour).
Style "top":  a small glyph in the upper half; the button keeps its text (it shows the value) at the
              bottom, so o is the bright disc, a shade darker, with a white glyph (the white text stays readable).

tools/make_tools.py puts these PNGs, with FireSystem's own (firesystem/FireSystemIcons.lua), into
plugins/FSIcons.lua.

Needs Pillow:  /usr/bin/python3 tools/make_mini_icons.py [--sheet out.png]
"""
import math
import os
import re
import sys

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "icons", "mini")
SIZE, SS = 128, 4          # final size, supersampling
PAD, RING = 6, 7           # as FireSystem's tools/make_round_icons.py
W = (255, 255, 255)

# same as FireSystem's ROUND_FAMILY_COLORS (dark idle, bright on)
FAMILY = {
    "red":     ((140, 0, 0),   (255, 20, 20)),
    "green":   ((0, 110, 20),  (0, 210, 60)),
    "blue":    ((0, 40, 160),  (0, 120, 255)),
    "orange":  ((150, 75, 0),  (255, 150, 0)),
    "purple":  ((100, 0, 130), (190, 40, 255)),
    "teal":    ((0, 105, 110), (0, 210, 215)),
    "yellow":  ((125, 110, 0), (235, 215, 0)),
    "magenta": ((130, 0, 110), (255, 0, 210)),
}


def mini_list():
    """[(name, style, family)] from MINI in src/FSIcons.lua"""
    text = open(os.path.join(ROOT, "src", "FSIcons.lua"), encoding="utf-8").read()
    block = re.search(r"^local MINI = \{(.*?)^\}", text, re.S | re.M)
    if not block:
        sys.exit("src/FSIcons.lua: no 'local MINI = {' list")
    return re.findall(r'\{"(\w+)",\s*"(top|full)",\s*"(\w+)"', block.group(1))


# ---- drawing: a canvas in 128 units, drawn at SS x --------------------------------------------
class G:
    def __init__(self):
        self.im = Image.new("RGBA", (SIZE * SS, SIZE * SS), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.im)

    @staticmethod
    def p(*xy):
        return [v * SS for v in xy]

    def col(self, a):
        return W + (int(255 * a),)

    def line(self, pts, w=8, a=1.0, round_ends=True):
        flat = [v * SS for xy in pts for v in xy]
        self.d.line(flat, fill=self.col(a), width=int(w * SS), joint="curve")
        if round_ends:
            for x, y in (pts[0], pts[-1]):
                self.dot(x, y, w / 2, a)

    def dot(self, x, y, r, a=1.0):
        self.d.ellipse(self.p(x - r, y - r, x + r, y + r), fill=self.col(a))

    def ring(self, x, y, r, w=7, a=1.0):
        self.d.ellipse(self.p(x - r, y - r, x + r, y + r), outline=self.col(a), width=int(w * SS))

    def poly(self, pts, a=1.0):
        self.d.polygon([(x * SS, y * SS) for x, y in pts], fill=self.col(a))

    def rect(self, x0, y0, x1, y1, a=1.0, r=3, outline=0):
        if outline:
            self.d.rounded_rectangle(self.p(x0, y0, x1, y1), radius=r * SS, outline=self.col(a), width=int(outline * SS))
        else:
            self.d.rounded_rectangle(self.p(x0, y0, x1, y1), radius=r * SS, fill=self.col(a))

    def clear_circle(self, x, y, r):
        self.d.ellipse(self.p(x - r, y - r, x + r, y + r), fill=(0, 0, 0, 0))

    def done(self):
        return self.im.resize((SIZE, SIZE), Image.LANCZOS)


def arrow(g, x0, y, x1, w=7, head=12):
    s = 1 if x1 > x0 else -1
    g.line([(x0, y), (x1 - s * head * 0.6, y)], w)
    g.poly([(x1, y), (x1 - s * head * 1.3, y - head), (x1 - s * head * 1.3, y + head)])


def tilt(deg):
    def draw(g):
        t = math.radians(deg)
        px = 64 - 40 * math.sin(t)
        py = 22
        ex, ey = px + 78 * math.sin(t), py + 78 * math.cos(t)
        g.line([(12, 106), (116, 106)], 7)
        g.line([(px, py), (ex, ey)], 7)
        g.dot(px, py, 10)
    return draw


def fx_size(n):
    def draw(g):
        for i, r in enumerate((16, 32, 48)):
            if i == n:
                g.ring(64, 64, r, 8)
            else:
                g.ring(64, 64, r, 4, 0.3)
        r = (16, 32, 48)[n]
        g.poly([(64 + 10, 64 - r), (64 - 6, 64 - r - 11), (64 - 6, 64 - r + 11)])   # direction on the ring
    return draw


def drop(g, a=1.0, outline=False):
    cx, cy, r, ay = 64, 78, 36, 10
    d = cy - ay
    phi = math.acos(r / d)          # tangent points, measured from straight up
    pts = [(64, ay)]
    steps = 48
    for k in range(steps + 1):
        ang = -math.pi / 2 + phi + k * (2 * math.pi - 2 * phi) / steps
        pts.append((cx + r * math.cos(ang), cy + r * math.sin(ang)))
    if outline:
        g.line(pts + [(64, ay)], 7)
    else:
        g.poly(pts, a)


def cp_normal(g):
    drop(g)


def cp_pastel(g):
    drop(g, 0.4)
    drop(g, outline=True)


def cp_dark(g):
    drop(g)
    # a crescent moon cut out of the drop
    g.clear_circle(60, 80, 20)
    g.dot(69, 73, 17)


def focus(g):
    g.ring(64, 64, 34, 7)
    for dx, dy in ((0, -1), (0, 1), (-1, 0), (1, 0)):
        g.line([(64 + dx * 24, 64 + dy * 24), (64 + dx * 52, 64 + dy * 52)], 7)
    g.dot(64, 64, 7)


def frost(g):
    for k in range(3):
        a = math.radians(90 + 60 * k)
        ux, uy = math.cos(a), math.sin(a)
        g.line([(64 - 52 * ux, 64 - 52 * uy), (64 + 52 * ux, 64 + 52 * uy)], 7)
        for s in (1, -1):
            bx, by = 64 + s * 32 * ux, 64 + s * 32 * uy
            for t in (1, -1):
                b = a + t * math.radians(45) + (math.pi if s < 0 else 0)
                g.line([(bx, by), (bx + 16 * math.cos(b), by + 16 * math.sin(b))], 6)


def color(g):
    box = G.p(14, 14, 114, 114)
    for k in range(6):
        g.d.pieslice(box, k * 60 - 90, k * 60 - 30, fill=g.col(1.0 if k % 2 == 0 else 0.45))
    g.clear_circle(64, 64, 18)


def shutter(g):
    g.rect(14, 14, 114, 114, r=4, outline=6)
    g.poly([(14, 14), (114, 14), (114, 34), (14, 46)])
    g.poly([(14, 114), (114, 114), (114, 90), (14, 100)])
    g.poly([(14, 14), (40, 14), (32, 114), (14, 114)], 0.6)
    g.poly([(114, 14), (92, 14), (98, 114), (114, 114)], 0.6)


def row(lit, arrow_dir=0, y=40):
    """six fixture cells; lit = {cell: alpha}"""
    def draw(g):
        for i in range(6):
            x = 12 + i * 18
            a = lit.get(i)
            if a:
                g.rect(x, y, x + 14, y + 30, a, r=3)
            else:
                g.rect(x, y, x + 14, y + 30, 1.0, r=3, outline=3)
        if arrow_dir > 0:
            arrow(g, 16, 96, 112)
        elif arrow_dir < 0:
            arrow(g, 112, 96, 16)
    return draw


def fade(g):
    g.poly([(14, 106), (114, 106), (114, 24)], 0.35)
    g.line([(14, 106), (114, 24)], 8)


def out(g):
    g.poly([(14, 106), (114, 106), (14, 24)], 0.35)
    g.line([(14, 24), (114, 106)], 8)


def hold(g):
    g.poly([(14, 106), (36, 28), (92, 28), (114, 106)], 0.3)
    g.line([(14, 106), (36, 28)], 6, 0.6)
    g.line([(92, 28), (114, 106)], 6, 0.6)
    g.line([(36, 28), (92, 28)], 9)


def delay(g):
    g.ring(64, 64, 48, 8)
    g.line([(64, 64), (64, 30)], 8)
    g.line([(64, 64), (88, 76)], 8)
    g.dot(64, 64, 7)


def speed(g):
    box = G.p(14, 22, 114, 122)
    g.d.arc(box, 180, 360, fill=g.col(1), width=8 * SS)
    for k in range(5):
        a = math.radians(180 + k * 45)
        g.line([(64 + 34 * math.cos(a), 72 + 34 * math.sin(a)), (64 + 42 * math.cos(a), 72 + 42 * math.sin(a))], 4, 0.6)
    a = math.radians(-40)
    g.line([(64, 72), (64 + 40 * math.cos(a), 72 + 40 * math.sin(a))], 7)
    g.dot(64, 72, 9)


def wings(g):
    g.line([(64, 16), (64, 112)], 5, 0.6)
    g.poly([(14, 64), (54, 30), (54, 98)])      # mirrored outwards from the middle
    g.poly([(114, 64), (74, 30), (74, 98)])


def sym(g):
    g.line([(64, 16), (64, 112)], 5, 0.6)
    g.poly([(54, 64), (14, 30), (14, 98)], 0.45)
    g.poly([(74, 64), (114, 30), (114, 98)], 0.45)
    arrow(g, 20, 64, 52, 6, 10)
    arrow(g, 108, 64, 76, 6, 10)


def phase(g):
    for off, a in ((0, 1.0), (1.6, 0.45)):
        pts = [(14 + k, 64 - 34 * math.sin((k / 100) * 2 * math.pi + off)) for k in range(0, 101, 2)]
        g.line(pts, 8 if a == 1 else 6, a)


def blocks(g):
    for i in range(6):
        x = 12 + i * 17 + (i // 2) * 4
        g.rect(x, 44, x + 13, 84, 1.0 if (i // 2) % 2 == 0 else 0.35, r=2)


def groups(g):
    for x, y in ((48, 50), (80, 50), (64, 78)):
        g.ring(x, y, 28, 6)


def steps(g):
    g.line([(14, 106), (14, 82), (47, 82), (47, 58), (80, 58), (80, 34), (114, 34)], 8)


def step(g):
    g.line([(14, 106), (14, 82), (47, 82), (47, 58), (80, 58), (80, 34), (114, 34)], 6, 0.4)
    g.rect(52, 32, 76, 54, 1.0, r=3)


def edit(g):
    a = math.radians(-45)
    ux, uy = math.cos(a), math.sin(a)          # along the pencil, tip at the bottom left
    nx, ny = -uy, ux
    tip = (20, 108)
    def at(t, s):
        return (tip[0] + ux * t + nx * s, tip[1] + uy * t + ny * s)
    g.poly([at(0, 0), at(26, 13), at(100, 13), at(100, -13), at(26, -13)])
    g.poly([at(84, 15), at(110, 15), at(110, -15), at(84, -15)], 0.5)
    g.line([(14, 118), (60, 118)], 4, 0.6)


def part(g):
    g.ring(64, 64, 46, 6)
    g.d.pieslice(G.p(18, 18, 110, 110), -90, 30, fill=g.col(1))


def master(g):
    g.line([(64, 14), (64, 114)], 6, 0.6)
    for y in (24, 44, 64, 84, 104):
        g.line([(30, y), (44, y)], 3, 0.6)
    g.rect(40, 44, 88, 64, 1.0, r=5)


GLYPHS = {
    "fade": fade, "delay": delay, "out": out, "hold": hold, "speed": speed,
    "wings": wings, "phase": phase, "blocks": blocks, "groups": groups, "sym": sym,
    "steps": steps, "step": step, "edit": edit, "part": part, "master": master,
    "color": color, "focus": focus, "frost": frost,
    "tilt_m90": tilt(-90), "tilt_m60": tilt(-60), "tilt_m45": tilt(-45), "tilt_m30": tilt(-30),
    "tilt_m10": tilt(-10), "tilt_p10": tilt(10), "tilt_p20": tilt(20), "tilt_p75": tilt(75),
    "fx_big": fx_size(2), "fx_mid": fx_size(1), "fx_small": fx_size(0),
    "dark": cp_dark, "normal": cp_normal, "pastel": cp_pastel, "shutter": shutter,
    "all_right": row({i: 1 for i in range(6)}, 1), "all_left": row({i: 1 for i in range(6)}, -1),
    "odd": row({0: 1, 2: 1, 4: 1}, y=49), "even": row({1: 1, 3: 1, 5: 1}, y=49),
    "third1": row({0: 1, 1: 1}, y=49), "third2": row({2: 1, 3: 1}, y=49), "third3": row({4: 1, 5: 1}, y=49),
    "chase": row({1: 0.25, 2: 0.55, 3: 1}, 1),
}


def glyph(name):
    g = G()
    GLYPHS[name](g)
    return g.done()


# ---- discs, as FireSystem's tools/make_round_icons.py -----------------------------------------
def disc(color, ring=False):
    big = SIZE * SS
    im = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    p = PAD * SS
    d.ellipse((p, p, big - p - 1, big - p - 1), fill=color + (255,))
    if ring:
        d.ellipse((p, p, big - p - 1, big - p - 1), outline=(255, 255, 255, 255), width=RING * SS)
    return im.resize((SIZE, SIZE), Image.LANCZOS)


def tinted(g, scale, alpha=1.0, color=W):
    a = g.split()[3]
    im = Image.new("RGBA", g.size, color + (0,))
    im.putalpha(a.point(lambda v: int(v * alpha)))
    s = int(SIZE * scale)
    return im.resize((s, s), Image.LANCZOS)


TOP_SCALE, TOP_Y = 0.40, 0.34     # "top": glyph size and centre height (of the button)
TOP_DIM = 0.8                     # "top": lit disc colour (of the bright family colour)


def place(base, g, style):
    if style == "top":
        x = (SIZE - g.size[0]) // 2
        y = int(SIZE * TOP_Y - g.size[1] / 2)
    else:
        x = y = (SIZE - g.size[0]) // 2
    base.alpha_composite(g, (x, y))
    return base


def images(name, style, family):
    """{file name: image} for one icon"""
    dark, bright = FAMILY[family]
    if style == "top":   # (a shade darker, so the white text on it stays readable)
        bright = tuple(int(c * TOP_DIM) for c in bright)
    g = glyph(name)
    scale = TOP_SCALE if style == "top" else 0.62
    out = {}
    sq = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    out["fs_mi_%s.png" % name] = place(sq, tinted(g, TOP_SCALE * 1.3) if style == "top" else g, style)
    states = (("i", dark, False, 0.85, W),
              ("o", (255, 255, 255), False, 1.0, bright) if style == "full" else ("o", bright, False, 1.0, W),
              ("p", bright, True, 1.0, W))
    for suffix, colour, ring, alpha, gcol in states:
        out["fs_r_mi_%s_%s.png" % (name, suffix)] = place(disc(colour, ring), tinted(g, scale, alpha, gcol), style)
    return out


def sheet(path, icons):
    """a contact sheet: per icon the square glyph and the three discs, with the text a top button keeps"""
    from PIL import ImageFont
    font = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Bold.ttf", 15)
    cols = 2
    rows = (len(icons) + cols - 1) // cols
    cw = SIZE * 4 + 40
    im = Image.new("RGBA", (cw * cols, rows * (SIZE + 26)), (30, 30, 30, 255))
    d = ImageDraw.Draw(im)
    for k, (name, style, family) in enumerate(icons):
        x0, y0 = (k % cols) * cw, (k // cols) * (SIZE + 26)
        imgs = images(name, style, family)
        for j, f in enumerate(["fs_mi_%s.png" % name] + ["fs_r_mi_%s_%s.png" % (name, s) for s in "iop"]):
            x = x0 + j * SIZE
            im.alpha_composite(imgs[f], (x, y0))
            if style == "top" and j > 0:
                tw = d.textlength("Fade 2s", font=font)
                d.text((x + (SIZE - tw) / 2, y0 + SIZE - 34), "Fade 2s", font=font, fill=(255, 255, 255, 255))
        d.text((x0 + 4, y0 + SIZE + 4), "%s (%s, %s)" % (name, style, family), font=font, fill=(200, 200, 200, 255))
    im.save(path)


def main():
    icons = mini_list()
    missing = [n for n, _, _ in icons if n not in GLYPHS]
    if missing:
        sys.exit("no drawing for: " + ", ".join(missing))
    if "--sheet" in sys.argv:
        sheet(sys.argv[sys.argv.index("--sheet") + 1], icons)
        return
    os.makedirs(OUT, exist_ok=True)
    keep = set()
    for name, style, family in icons:
        for f, im in images(name, style, family).items():
            im.save(os.path.join(OUT, f), optimize=True)
            keep.add(f)
    for f in os.listdir(OUT):
        if f.endswith(".png") and f not in keep:
            os.remove(os.path.join(OUT, f))
    print(len(keep), "images in", os.path.relpath(OUT, ROOT))


if __name__ == "__main__":
    main()
