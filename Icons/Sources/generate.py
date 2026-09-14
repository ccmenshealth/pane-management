import os, math, json
import cairosvg

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
SRC  = os.path.join(ROOT, "Sources")
LAY  = os.path.join(ROOT, "IconComposer-Layers")
APP  = os.path.join(ROOT, "Assets.xcassets", "AppIcon.appiconset")
ICO  = os.path.join(ROOT, "AppIcon.iconset")
for d in (SRC, LAY, APP, ICO):
    os.makedirs(d, exist_ok=True)

BG_STOPS  = [(0.00, "#0A0120"), (0.50, "#2A0755"), (1.00, "#551180")]
SUN_STOPS = [(0.00, "#FFE98A"), (0.24, "#FFBE33"), (0.47, "#FF7A2F"),
             (0.68, "#D93B4A"), (0.86, "#8E2FA8"), (1.00, "#4A1580")]
USE_PLATE = True

BODY = "#FF2D95"
NEON = "#A855F7"

def _rgb(c):
    c = c.lstrip("#")
    return tuple(int(c[i:i+2], 16) for i in (0, 2, 4))

def ramp(stops, t):
    t = max(0.0, min(1.0, t))
    for i in range(len(stops) - 1):
        p0, c0 = stops[i]
        p1, c1 = stops[i + 1]
        if p0 <= t <= p1:
            f = 0.0 if p1 == p0 else (t - p0) / (p1 - p0)
            a, b = _rgb(c0), _rgb(c1)
            return "#%02X%02X%02X" % tuple(round(a[j] + (b[j] - a[j]) * f) for j in range(3))
    return stops[-1][1]

def sun_color(t):
    return ramp(SUN_STOPS, t)

BG_TOP, BG_MID, BG_BOT = BG_STOPS[0][1], BG_STOPS[1][1], BG_STOPS[2][1]
PLATE = ramp(BG_STOPS, 1.0 / 3.0)

CAP   = dict(x=324, y=165, w=376, h=139, r=30)
BOT   = dict(x=283, y=317, w=458, h=542, r=53)
PLT   = dict(x=343, y=425, w=338, h=327, r=25)
PANES = [(368, 450), (525, 450), (368, 602), (525, 602)]
PW, PH, PR = 131, 125, 13

def hdr(extra=""):
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" '
            'viewBox="0 0 1024 1024">' + extra)

def layer_background():
    return hdr(
        f'<defs><linearGradient id="bg" x1="0" y1="0" x2="0" y2="1">'
        f'<stop offset="0" stop-color="{BG_TOP}"/>'
        f'<stop offset="1" stop-color="{BG_BOT}"/></linearGradient></defs>'
        f'<rect width="1024" height="1024" fill="url(#bg)"/></svg>')

SUN_CY, SUN_R = 512.0, 336.0

def layer_sun():
    top, bottom = SUN_CY - SUN_R, SUN_CY + SUN_R
    parts = ['<rect x="150" y="%.1f" width="724" height="%.1f" fill="url(#sunTop)"/>'
             % (top, SUN_R)]
    y, h, gap = SUN_CY, 43.0, 8.0
    while y < bottom and h >= 3.5:
        seg = min(h, bottom - y)
        t = (y + seg / 2.0 - top) / (2.0 * SUN_R)
        parts.append('<rect x="150" y="%.1f" width="724" height="%.1f" fill="%s"/>'
                     % (y, seg, sun_color(t)))
        y += seg + gap
        h *= 0.86
        gap *= 1.18
    defs = ('<defs><linearGradient id="sunTop" x1="0" y1="0" x2="0" y2="1">'
            '<stop offset="0" stop-color="%s"/>'
            '<stop offset="1" stop-color="%s"/></linearGradient>'
            '<clipPath id="s"><circle cx="512" cy="%.0f" r="%.0f"/></clipPath></defs>'
            % (sun_color(0.0), sun_color(0.5), SUN_CY, SUN_R))
    return hdr(defs + '<g clip-path="url(#s)">' + "".join(parts) + '</g></svg>')

def layer_body():
    b = BOT
    return hdr(f'<rect x="{b["x"]}" y="{b["y"]}" width="{b["w"]}" height="{b["h"]}" '
               f'rx="{b["r"]}" fill="{BODY}"/></svg>')

def layer_plate():
    p = PLT
    return hdr(f'<rect x="{p["x"]}" y="{p["y"]}" width="{p["w"]}" height="{p["h"]}" '
               f'rx="{p["r"]}" fill="{PLATE}"/></svg>')

def layer_neon():
    c = CAP
    parts = [f'<rect x="{c["x"]}" y="{c["y"]}" width="{c["w"]}" height="{c["h"]}" '
             f'rx="{c["r"]}" fill="{NEON}"/>']
    for px, py in PANES:
        parts.append(f'<rect x="{px}" y="{py}" width="{PW}" height="{PH}" rx="{PR}" fill="{NEON}"/>')
    return hdr("".join(parts) + '</svg>')

_stack = [("Background", layer_background), ("Sun", layer_sun), ("BottleBody", layer_body)]
if USE_PLATE:
    _stack.append(("LabelPlate", layer_plate))
_stack.append(("Accents", layer_neon))
LAYERS = [("%d-%s.svg" % (i, n), f()) for i, (n, f) in enumerate(_stack)]
for name, data in LAYERS:
    open(os.path.join(LAY, name), "w").write(data)

def squircle_path(x, y, size, n=4.6, steps=720):
    a = size / 2.0
    cx, cy = x + a, y + a
    pts = []
    for i in range(steps):
        t = 2.0 * math.pi * i / steps
        ct, st = math.cos(t), math.sin(t)
        pts.append("%.3f,%.3f" % (
            cx + a * math.copysign(abs(ct) ** (2.0 / n), ct),
            cy + a * math.copysign(abs(st) ** (2.0 / n), st)))
    return "M" + " L".join(pts) + " Z"

def inner(svg):
    return svg.split(">", 1)[1].rsplit("</svg>", 1)[0]

def flattened():
    sq = squircle_path(100, 100, 824)
    body = "".join(inner(d) for _, d in LAYERS)
    body = body.replace('id="bg"', 'id="bgF"').replace('url(#bg)', 'url(#bgF)')
    body = body.replace('id="s"', 'id="sF"').replace('url(#s)', 'url(#sF)')
    body = body.replace('id="sunTop"', 'id="sunTopF"').replace('url(#sunTop)', 'url(#sunTopF)')
    return (hdr(f'<defs><clipPath id="mask"><path d="{sq}"/></clipPath></defs>'
                f'<g clip-path="url(#mask)">'
                f'<g transform="translate(100,100) scale(0.8047)">{body}</g></g></svg>'))

flat_path = os.path.join(SRC, "AppIcon-Cyberpunk-Flat.svg")
open(flat_path, "w").write(flattened())

renders = [("icon_16x16.png",16),("icon_16x16@2x.png",32),("icon_32x32.png",32),
           ("icon_32x32@2x.png",64),("icon_128x128.png",128),("icon_128x128@2x.png",256),
           ("icon_256x256.png",256),("icon_256x256@2x.png",512),("icon_512x512.png",512),
           ("icon_512x512@2x.png",1024)]
for fname, px in renders:
    png = cairosvg.svg2png(url=flat_path, output_width=px, output_height=px)
    open(os.path.join(APP, fname), "wb").write(png)
    open(os.path.join(ICO, fname), "wb").write(png)

for name, data in LAYERS:
    cairosvg.svg2png(bytestring=data.encode(), output_width=1024, output_height=1024,
                     write_to=os.path.join(LAY, name.replace(".svg", ".png")))

MB = os.path.join(ROOT, "Assets.xcassets", "MenuBarIconTemplate.imageset")
os.makedirs(MB, exist_ok=True)
MENUBAR_SVG = """<svg xmlns="http://www.w3.org/2000/svg" width="14" height="18" viewBox="0 0 14 18">
<rect x="2.5" y="0.75" width="9" height="3.3" rx="0.9" fill="#000000"/>
<rect x="1.5" y="5.6" width="11" height="10.9" rx="2" fill="none" stroke="#000000" stroke-width="1.5"/>
<rect x="3.4" y="8.05" width="2.8" height="6" rx="0.7" fill="#000000"/>
<rect x="7.8" y="8.05" width="2.8" height="6" rx="0.7" fill="#000000"/>
</svg>"""
mb_src = os.path.join(SRC, "MenuBarIconTemplate.svg")
open(mb_src, "w").write(MENUBAR_SVG)
cairosvg.svg2pdf(url=mb_src, write_to=os.path.join(MB, "MenuBarIconTemplate.pdf"),
                 output_width=14, output_height=18)
for suffix, px in (("", 1), ("@2x", 2)):
    cairosvg.svg2png(url=mb_src, output_width=14 * px, output_height=18 * px,
                     write_to=os.path.join(SRC, "MenuBarIconTemplate%s.png" % suffix))

app_contents = {"images": [], "info": {"version": 1, "author": "xcode"}}
for fname, px in renders:
    scale = "2x" if "@2x" in fname else "1x"
    base = px // 2 if scale == "2x" else px
    app_contents["images"].append({"filename": fname, "idiom": "mac",
                                   "scale": scale, "size": "%dx%d" % (base, base)})
json.dump(app_contents, open(os.path.join(APP, "Contents.json"), "w"), indent=2)
json.dump({"images": [{"filename": "MenuBarIconTemplate.pdf", "idiom": "mac", "scale": "1x"},
                      {"idiom": "mac", "scale": "2x"}],
           "info": {"version": 1, "author": "xcode"},
           "properties": {"template-rendering-intent": "template",
                          "preserves-vector-representation": True}},
          open(os.path.join(MB, "Contents.json"), "w"), indent=2)
json.dump({"info": {"version": 1, "author": "xcode"}},
          open(os.path.join(ROOT, "Assets.xcassets", "Contents.json"), "w"), indent=2)

print("BODY", BODY, "NEON", NEON, "PLATE", PLATE)
print("done")
