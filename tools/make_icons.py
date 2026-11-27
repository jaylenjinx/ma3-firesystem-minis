#!/usr/bin/env python3
"""Draws FS Icons' own images: the buttons FireSystem has no icon for (icons/mini/*.png).

Same look as FireSystem's round icons (tools/make_round_icons.py in ma3-fire-system):
  fs_m_<name>.png      the glyph, white on transparent (the "keep colour and text" look)
  fs_m_<name>_i.png    idle: the glyph on a dark disc of its colour family
  fs_m_<name>_o.png    on: white disc, the glyph in the bright family colour
  fs_t_<name>.png      "top" glyphs for value buttons (Wings Off, Fade 0.5 ...): the glyph in the
                       top half, the button's own colour behind it and its text under it
  fs_sw_<slug>_i/o.png colour swatch discs (Colour Picker): dark / bright with a white ring

icons/mini/order.txt keeps FS Icons' image numbering (Image 3.3101+ in that order): new images are
added at the end, so a show made with an older FS Icons keeps its numbers.
Glyphs cut from FireSystem's own caption art (fs_c_*.png in firesystem/FireSystemIcons.lua) keep
their look; the rest are drawn here.

    python3 tools/make_icons.py            # writes icons/mini/ and icons/mini/preview.png
Needs Pillow.
"""
import base64, math, os, re, sys
from io import BytesIO
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "icons", "mini")
PACK = os.path.join(ROOT, "firesystem", "FireSystemIcons.lua")
SIZE, SS, PAD = 128, 4, 6
FONT = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"
if not os.path.exists(FONT):
    FONT = "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf"

# as FireSystem's ROUND_FAMILY_COLORS (dark idle, bright on)
FAMILY = {
    "red": ((140, 0, 0), (255, 20, 20)), "green": ((0, 110, 20), (0, 210, 60)),
    "blue": ((0, 40, 160), (0, 120, 255)), "orange": ((150, 75, 0), (255, 150, 0)),
    "purple": ((100, 0, 130), (190, 40, 255)), "teal": ((0, 105, 110), (0, 210, 215)),
    "yellow": ((125, 110, 0), (235, 215, 0)), "magenta": ((130, 0, 110), (255, 0, 210)),
}
# as FireSystem's CFG.COLORS
COLOURS = [("White", (255, 255, 255)), ("Warm", (253, 235, 161)), ("Red", (233, 0, 3)), ("Orange", (239, 93, 7)),
           ("Yellow", (251, 255, 12)), ("Lime", (160, 255, 13)), ("Green", (21, 255, 10)), ("Sea Green", (21, 255, 106)),
           ("Cyan", (22, 255, 252)), ("Sky Blue", (16, 162, 248)), ("Blue", (4, 0, 243)), ("Deep Blue", (2, 0, 104)),
           ("Violet", (94, 0, 244)), ("Magenta", (233, 0, 244)), ("Pink", (233, 1, 149))]
W = (255, 255, 255, 255)
PINK = (255, 90, 185, 255)


def pack():
    """FireSystem's images by file name (PIL images)"""
    s = open(PACK, encoding="utf-8").read()
    return {n: Image.open(BytesIO(base64.b64decode(b))).convert("RGBA")
            for n, b in re.findall(r'D\["(fs_[^"]+\.png)"\] = "([^"]+)"', s)}


def canvas():
    big = SIZE * SS
    im = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    return im, ImageDraw.Draw(im), big


def done(im):
    return im.resize((SIZE, SIZE), Image.LANCZOS)


def text(d, t, cx, cy, size, ink=W):
    f = ImageFont.truetype(FONT, size)
    b = d.textbbox((0, 0), t, font=f)
    d.text((cx - (b[2] - b[0]) / 2 - b[0], cy - (b[3] - b[1]) / 2 - b[1]), t, font=f, fill=ink)


# ---- drawn glyphs (white on transparent, 128 px) -------------------------------------------
def tilt(deg):
    """FireSystem's tilt glyph: the head at the top, the beam deg from straight down, the floor"""
    im, d, s = canvas()
    u = s / 128
    mirror = deg < -25          # (big backwards tilts: drawn as the forward one, mirrored)
    a = abs(deg) if mirror else deg
    hx, hy = 42 * u, 22 * u
    dx, dy = math.sin(math.radians(a)), math.cos(math.radians(a))
    # the beam runs to the floor (y 106) or the right edge (x 118), whichever comes first
    t = min((106 * u - hy) / dy if dy > 1e-6 else 1e9, (118 * u - hx) / dx if dx > 1e-6 else 1e9,
            (hx - 10 * u) / -dx if dx < -1e-6 else 1e9)
    d.line((hx, hy, hx + dx * t, hy + dy * t), fill=W, width=int(4 * u))
    d.line((12 * u, 106 * u, 118 * u, 106 * u), fill=W, width=int(4 * u))
    d.ellipse((hx - 9 * u, hy - 9 * u, hx + 9 * u, hy + 9 * u), fill=W)
    g = done(im)
    return g.transpose(Image.FLIP_LEFT_RIGHT) if mirror else g


def size(k):
    """FX size: a ring, small / medium / big, with a dot in the middle"""
    im, d, s = canvas()
    r = s * (0.14, 0.25, 0.36)[k]
    c = s / 2
    d.ellipse((c - r, c - r, c + r, c + r), outline=W, width=int(s * 0.055))
    d.ellipse((c - s * 0.04, c - s * 0.04, c + s * 0.04, c + s * 0.04), fill=W)
    return done(im)


def dots(lit, arrow=None, n=None):
    """LOS bumps: a row of fixtures, the lit ones filled; arrow > or < under them"""
    im, d, s = canvas()
    n = n or len(lit)
    gap = 0.62 / (n - 1)
    r = s * min(0.065, gap * 0.38)
    for i in range(n):
        cx, cy = s * (0.19 + i * gap), s * 0.42
        box = (cx - r, cy - r, cx + r, cy + r)
        if lit[i]:
            d.ellipse(box, fill=W)
        else:
            d.ellipse(box, outline=W, width=int(s * 0.022))
    if arrow:
        y = s * 0.66
        x0, x1 = s * 0.22, s * 0.78
        if arrow == "<":
            x0, x1 = x1, x0
        d.line((x0, y, x1, y), fill=W, width=int(s * 0.04))
        k = s * 0.07 * (1 if arrow == ">" else -1)
        d.polygon([(x1 + k * 0.6, y), (x1 - k, y - abs(k)), (x1 - k, y + abs(k))], fill=W)
    return done(im)


def chase():
    """LOS chase: three fixtures lighting one after the other (growing), with a run arrow"""
    im, d, s = canvas()
    for i, r in enumerate((0.045, 0.07, 0.095)):
        cx, cy = s * (0.25 + i * 0.25), s * 0.42
        d.ellipse((cx - s * r, cy - s * r, cx + s * r, cy + s * r), fill=W)
    y = s * 0.68
    d.arc((s * 0.2, s * 0.5, s * 0.8, s * 0.86), 200, 340, fill=W, width=int(s * 0.04))
    d.polygon([(s * 0.79, s * 0.58), (s * 0.7, s * 0.6), (s * 0.78, s * 0.67)], fill=W)
    return done(im)


def steps():
    """Steps (Go+): a staircase going up to the right"""
    im, d, s = canvas()
    pts = [(0.2, 0.75), (0.2, 0.62), (0.4, 0.62), (0.4, 0.48), (0.6, 0.48), (0.6, 0.34), (0.8, 0.34), (0.8, 0.75)]
    d.polygon([(x * s, y * s) for x, y in pts], fill=W)
    d.line((s * 0.26, s * 0.26, s * 0.46, s * 0.26), fill=W, width=int(s * 0.035))
    d.polygon([(s * 0.52, s * 0.26), (s * 0.44, s * 0.21), (s * 0.44, s * 0.31)], fill=W)
    return done(im)


def master():
    """Master: a crown"""
    im, d, s = canvas()
    pts = [(0.2, 0.7), (0.2, 0.34), (0.36, 0.5), (0.5, 0.28), (0.64, 0.5), (0.8, 0.34), (0.8, 0.7)]
    d.polygon([(x * s, y * s) for x, y in pts], fill=W)
    d.rectangle((s * 0.2, s * 0.74, s * 0.8, s * 0.8), fill=W)
    for x, y in ((0.2, 0.3), (0.5, 0.24), (0.8, 0.3)):
        d.ellipse((s * (x - 0.04), s * (y - 0.04), s * (x + 0.04), s * (y + 0.04)), fill=W)
    return done(im)


def focus():
    """Focus: a sharp ring with corner brackets"""
    im, d, s = canvas()
    c = s / 2
    d.ellipse((c - s * 0.13, c - s * 0.13, c + s * 0.13, c + s * 0.13), fill=W)
    w = int(s * 0.045)
    for sx in (-1, 1):
        for sy in (-1, 1):
            x, y = c + sx * s * 0.3, c + sy * s * 0.3
            d.line((x, y, x - sx * s * 0.13, y), fill=W, width=w)
            d.line((x, y, x, y - sy * s * 0.13), fill=W, width=w)
    return done(im)


def frost():
    """Frost: a snowflake"""
    im, d, s = canvas()
    c = s / 2
    w = int(s * 0.04)
    for k in range(6):
        a = math.radians(k * 60 + 90)
        ex, ey = c + math.cos(a) * s * 0.32, c - math.sin(a) * s * 0.32
        d.line((c, c, ex, ey), fill=W, width=w)
        for side in (-1, 1):
            b = a + side * math.radians(40)
            mx, my = c + math.cos(a) * s * 0.2, c - math.sin(a) * s * 0.2
            d.line((mx, my, mx + math.cos(b) * s * 0.1, my - math.sin(b) * s * 0.1), fill=W, width=w)
    return done(im)


def tint(kind):
    """Colour Picker tints: Normal = a full disc, Pastel = a disc with a pale halo, Dark = half dark"""
    im, d, s = canvas()
    c, r = s / 2, s * 0.24
    if kind == "normal":
        d.ellipse((c - r, c - r, c + r, c + r), fill=W)
    elif kind == "pastel":
        d.ellipse((c - r * 1.35, c - r * 1.35, c + r * 1.35, c + r * 1.35), fill=(255, 255, 255, 90))
        d.ellipse((c - r, c - r, c + r, c + r), fill=(255, 255, 255, 200))
    else:
        d.ellipse((c - r, c - r, c + r, c + r), outline=W, width=int(s * 0.04))
        d.pieslice((c - r, c - r, c + r, c + r), 90, 270, fill=W)
    return done(im)


def nsteps(n):
    """Colour FX step count: the number big, STEPS under it (as FireSystem's 1-3 Step discs)"""
    im, d, s = canvas()
    text(d, str(n), s / 2, s * 0.43, int(s * 0.42))
    text(d, "STEPS", s / 2, s * 0.73, int(s * 0.12))
    return done(im)


def sym():
    """Sym: two halves mirrored round a dashed line"""
    im, d, s = canvas()
    c = s / 2
    for y in range(int(s * 0.14), int(s * 0.86), int(s * 0.1)):
        d.line((c, y, c, y + s * 0.05), fill=W, width=int(s * 0.03))
    d.polygon([(c - s * 0.06, s * 0.3), (c - s * 0.06, s * 0.7), (c - s * 0.34, s * 0.7)], fill=W)
    d.polygon([(c + s * 0.06, s * 0.3), (c + s * 0.06, s * 0.7), (c + s * 0.34, s * 0.7)], outline=W, width=int(s * 0.03))
    return done(im)


def hold():
    """Hold: a pause sign"""
    im, d, s = canvas()
    for x in (0.34, 0.56):
        d.rounded_rectangle((s * x, s * 0.26, s * (x + 0.1), s * 0.74), radius=s * 0.02, fill=W)
    return done(im)


def stepcount():
    """Bumps' Step Count: three stacked bars, like steps"""
    im, d, s = canvas()
    for i, w in enumerate((0.24, 0.4, 0.56)):
        y = s * (0.3 + i * 0.16)
        d.rounded_rectangle((s * 0.22, y, s * (0.22 + w), y + s * 0.1), radius=s * 0.02, fill=W)
    return done(im)


def step_ring(n):
    """Colour FX STEP n: the number in a ring (pink, as FireSystem's STEP captions)"""
    im, d, s = canvas()
    c, r = s / 2, s * 0.3
    d.ellipse((c - r, c - r, c + r, c + r), outline=PINK, width=int(s * 0.05))
    text(d, str(n), c, c, int(s * 0.36), PINK)
    return done(im)


# ---- glyphs cut from FireSystem's caption art ---------------------------------------------
def cut(img, top=0.0, bottom=0.42):
    """the icon part of a caption image (its label is below), centred on a square"""
    w, h = img.size
    part = img.crop((0, int(h * top), w, int(h * bottom)))
    bb = part.getbbox()
    part = part.crop(bb)
    sq = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    k = min(SIZE * 0.6 / part.size[0], SIZE * 0.6 / part.size[1])
    part = part.resize((max(1, int(part.size[0] * k)), max(1, int(part.size[1] * k))), Image.LANCZOS)
    sq.alpha_composite(part, ((SIZE - part.size[0]) // 2, (SIZE - part.size[1]) // 2))
    return sq


def topify(g, scale=0.5):
    """a top glyph: the glyph shrunk into the upper part of the button (the text goes under it)"""
    bb = g.getbbox()
    g = g.crop(bb)
    k = min(SIZE * scale / g.size[0], SIZE * 0.42 / g.size[1])
    g = g.resize((max(1, int(g.size[0] * k)), max(1, int(g.size[1] * k))), Image.LANCZOS)
    out = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    out.alpha_composite(g, ((SIZE - g.size[0]) // 2, int(SIZE * 0.3 - g.size[1] / 2)))
    return out


def disc(color, ring=False):
    im, d, s = canvas()
    p = PAD * SS
    d.ellipse((p, p, s - p - 1, s - p - 1), fill=tuple(color) + (255,))
    if ring:
        d.ellipse((p, p, s - p - 1, s - p - 1), outline=W, width=7 * SS)
    return done(im)


def recolour(g, rgb, alpha=1.0):
    a = g.split()[3].point(lambda v: int(v * alpha))
    out = Image.new("RGBA", g.size, tuple(rgb) + (0,))
    out.putalpha(a)
    return out


def bake(g, family, scale=1.0):
    dark, bright = FAMILY[family]
    if scale != 1.0:   # (full-canvas glyphs, like FireSystem's own: 62 % of the disc)
        k = int(SIZE * scale)
        small = g.resize((k, k), Image.LANCZOS)
        g = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
        g.alpha_composite(small, ((SIZE - k) // 2, (SIZE - k) // 2))
    i = disc(dark)
    i.alpha_composite(recolour(g, (255, 255, 255), 0.85))
    o = disc((255, 255, 255))
    o.alpha_composite(recolour(g, bright))
    return i, o


def icons(P):
    """(name, family or None for top glyphs, glyph) in MINI_ICONS order"""
    L = []
    for deg in (-90, -60, -45, -30, -10, 10, 20, 75):
        L.append(("tilt_" + ("m" if deg < 0 else "") + str(abs(deg)), "teal", tilt(deg)))
    for k, n in enumerate(("size_s", "size_m", "size_b")):
        L.append((n, "magenta", size(k)))
    L += [("los_right", "red", dots([1, 1, 1, 1], ">")), ("los_left", "red", dots([1, 1, 1, 1], "<")),
          ("los_odd", "red", dots([1, 0, 1, 0])), ("los_even", "red", dots([0, 1, 0, 1])),
          ("los_third1", "red", dots([1, 0, 0, 1, 0, 0])), ("los_third2", "red", dots([0, 1, 0, 0, 1, 0])),
          ("los_third3", "red", dots([0, 0, 1, 0, 0, 1])), ("los_chase", "red", chase()),
          ("steps", "orange", steps()), ("master", "orange", master()),
          ("palette", "teal", cut(P["fs_c_color.png"], 0.0, 1.0).crop((0, 0, SIZE, SIZE))),
          ("focus", "teal", focus()), ("frost", "teal", frost()),
          ("tint_normal", "purple", tint("normal")), ("tint_pastel", "purple", tint("pastel")),
          ("tint_dark", "purple", tint("dark"))]
    for n in (2, 3, 4, 5):
        L.append(("steps%d" % n, "purple", nsteps(n)))
    # top glyphs (value buttons): FireSystem's caption icons, and a few new ones
    for name, src in (("wings", "wings"), ("block", "block"), ("group", "group"), ("phase", "phase"),
                      ("delay", "delay"), ("fade", "fade"), ("speed", "speed"), ("part", "part"),
                      ("offtime", "offtime"), ("fadeout", "fadeout")):
        L.append(("t_" + name, None, topify(cut(P["fs_c_%s.png" % src]))))
    L += [("t_sym", None, topify(sym())), ("t_hold", None, topify(hold())),
          ("t_edit", None, topify(P["fs_pen.png"])), ("t_stepcount", None, topify(stepcount()))]
    for n in range(1, 6):
        L.append(("t_step%d" % n, None, topify(step_ring(n))))
    return L


def slug(name):
    return name.lower().replace(" ", "_")


def main():
    os.makedirs(OUT, exist_ok=True)
    for f in os.listdir(OUT):
        if f.endswith(".png"):
            os.remove(os.path.join(OUT, f))
    P = pack()
    # (the palette glyph: the left part of the Color caption, without its word)
    col = P["fs_c_color.png"]
    w, h = col.size
    P["fs_c_color.png"] = col.crop((0, 0, int(w * 0.34), h))
    files, preview = [], []
    for name, family, g in icons(P):
        if family:
            g.save(os.path.join(OUT, "fs_m_%s.png" % name))
            i, o = bake(g, family, 0.62 if name.startswith("tilt_") else 1.0)
            i.save(os.path.join(OUT, "fs_m_%s_i.png" % name))
            o.save(os.path.join(OUT, "fs_m_%s_o.png" % name))
            files += ["fs_m_%s.png" % name, "fs_m_%s_i.png" % name, "fs_m_%s_o.png" % name]
            preview += [i, o]
        else:
            g.save(os.path.join(OUT, "fs_%s.png" % name))
            files.append("fs_%s.png" % name)
            bg = Image.new("RGBA", (SIZE, SIZE), (46, 46, 46, 255))
            bg.alpha_composite(g)
            preview.append(bg)
    for cname, rgb in COLOURS:
        dark = tuple(int(v * 0.45) for v in rgb)
        disc(dark).save(os.path.join(OUT, "fs_sw_%s_i.png" % slug(cname)))
        disc(rgb, True).save(os.path.join(OUT, "fs_sw_%s_o.png" % slug(cname)))
        files += ["fs_sw_%s_i.png" % slug(cname), "fs_sw_%s_o.png" % slug(cname)]
        preview += [disc(dark), disc(rgb, True)]
    # the image order FS Icons numbers them by (Image 3.3101+): new images go at the end
    order = os.path.join(OUT, "order.txt")
    old = [l.strip() for l in open(order)] if os.path.exists(order) else []
    keep = [f for f in old if f in files] + [f for f in files if f not in old]
    if len(keep) != len([f for f in old if f in files]) + len([f for f in files if f not in old]) or set(old) - set(files):
        sys.exit("an image was dropped from the list: FS Icons' numbers would shift (only add at the end)")
    open(order, "w").write("\n".join(keep) + "\n")
    cols = 16
    rows = (len(preview) + cols - 1) // cols
    sheet = Image.new("RGBA", (cols * (SIZE + 8), rows * (SIZE + 8)), (30, 30, 30, 255))
    for k, im in enumerate(preview):
        sheet.alpha_composite(im, ((k % cols) * (SIZE + 8), (k // cols) * (SIZE + 8)))
    sheet.save(os.path.join(ROOT, "icons", "preview.png"))
    print(len([f for f in os.listdir(OUT) if f.endswith(".png")]), "images in", OUT)


if __name__ == "__main__":
    main()
