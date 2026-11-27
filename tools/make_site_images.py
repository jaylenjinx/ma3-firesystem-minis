#!/usr/bin/env python3
"""Draws the site's layout pictures (docs/img/FS<Tool>.png).

Each tool is built in the MA stand-in with 4 groups and FS Icons run over it
(tools/site_layout.lua), then its buttons are drawn as an HTML page and saved as a PNG with
headless Chrome at 2x.

    python3 tools/make_site_images.py            # every tool with a picture on the site
    python3 tools/make_site_images.py FSLOS      # one tool
    python3 tools/make_site_images.py --plain    # without FS Icons
Needs Lua 5.4 and Google Chrome (CHROME=/path/to/chrome to use another).
"""
import base64, html, os, re, subprocess, sys, tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TOOLS = ["FSColourPicker", "FSPositionPicker", "FSDimmerFX", "FSColourFX", "FSGoboBeam", "FSLOS", "FSBumps"]
CHROME = os.environ.get("CHROME", "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome")
MARGIN, SCALE = 15, 2


def images():
    """every icon image by file name, as base64 PNG"""
    out = {}
    fs = open(os.path.join(ROOT, "firesystem", "FireSystemIcons.lua"), encoding="utf-8").read()
    for name, b64 in re.findall(r'^D\["([^"]+)"\]\s*=\s*"([^"]*)"', fs, flags=re.M):
        out[name] = b64
    mini = os.path.join(ROOT, "icons", "mini")
    for f in os.listdir(mini):
        if f.endswith(".png"):
            out[f] = base64.b64encode(open(os.path.join(mini, f), "rb").read()).decode()
    return out


def buttons(tool, plain):
    cmd = ["lua", "tools/site_layout.lua", tool] + (["plain"] if plain else [])
    text = subprocess.run(cmd, cwd=ROOT, check=True, capture_output=True, text=True).stdout
    out = []
    for line in text.splitlines():
        x, y, w, h, bg, img, tint, border, label = (line.split("\t") + [""] * 9)[:9]
        out.append(dict(x=int(x), y=-int(y), w=int(w), h=int(h), bg=[int(v) for v in bg.split(",")],
                        img=img, border=border == "1", text=label))
    return out


def page(btns, imgs):
    x0, y0 = min(b["x"] for b in btns), min(b["y"] for b in btns)
    W = max(b["x"] + b["w"] for b in btns) - x0 + 2 * MARGIN
    H = max(b["y"] + b["h"] for b in btns) - y0 + 2 * MARGIN
    parts = []
    for b in btns:
        r, g, bl, a = b["bg"]
        style = ["left:%dpx" % (b["x"] - x0 + MARGIN), "top:%dpx" % (b["y"] - y0 + MARGIN),
                 "width:%dpx" % b["w"], "height:%dpx" % b["h"], "background-color:rgba(%d,%d,%d,%.3f)" % (r, g, bl, a / 255)]
        if b["border"]:
            style.append("box-shadow:inset 0 0 0 1px rgba(255,255,255,0.12)")
        cls = "b"
        if a > 128 and 0.299 * r + 0.587 * g + 0.114 * bl > 160:
            cls += " light"   # dark text on a light button
        if b["img"]:
            data = imgs.get(b["img"])
            if data is None:
                sys.exit("no image %s" % b["img"])
            style.append("background-image:url(data:image/png;base64,%s)" % data)
            if b["img"].startswith("fs_t_"):
                cls += " top"
        parts.append('<div class="%s" style="%s"><span>%s</span></div>' % (cls, ";".join(style), html.escape(b["text"])))
    doc = """<!doctype html><html><head><meta charset="utf-8"><style>
html,body{margin:0;background:#151515;width:%dpx;height:%dpx;overflow:hidden}
.b{position:absolute;box-sizing:border-box;border-radius:2px;background-size:100%% 100%%;display:flex;
   align-items:center;justify-content:center;text-align:center;color:#eee;font:9px/1.15 "Helvetica Neue",Helvetica,Arial,sans-serif}
.b span{padding:0 2px}
.b.light{color:#222}
.b.top{align-items:flex-end}.b.top span{padding-bottom:5px}
</style></head><body>%s</body></html>""" % (W, H, "\n".join(parts))
    return doc, W, H


def shoot(doc, W, H, out):
    with tempfile.TemporaryDirectory() as d:
        p = os.path.join(d, "page.html")
        open(p, "w", encoding="utf-8").write(doc)
        subprocess.run([CHROME, "--headless", "--disable-gpu", "--hide-scrollbars", "--force-device-scale-factor=%d" % SCALE,
                        "--window-size=%d,%d" % (W, H), "--screenshot=%s" % out, "file://" + p],
                       check=True, capture_output=True)


def main():
    plain = "--plain" in sys.argv
    tools = [a for a in sys.argv[1:] if not a.startswith("--")] or TOOLS
    imgs = images()
    for tool in tools:
        doc, W, H = page(buttons(tool, plain), imgs)
        out = os.path.join(ROOT, "docs", "img", tool + ".png")
        shoot(doc, W, H, out)
        print("wrote", os.path.relpath(out, ROOT), "%dx%d" % (W * SCALE, H * SCALE))


if __name__ == "__main__":
    main()
