# Pane Management — icon pack

Prescription-bottle app icon in a synthwave palette, plus a monochrome menu bar
glyph. Built for macOS 26 layered icons with a flat fallback for macOS 15 and
earlier.

## Contents

```
IconComposer-Layers/          layer SVGs (+PNG previews), unmasked, 1024pt
Assets.xcassets/
  AppIcon.appiconset/         flat PNGs, fallback for macOS 15 and earlier
  MenuBarIconTemplate.imageset/ vector PDF, flagged as a template image
AppIcon.iconset/              same flat PNGs, for iconutil
Sources/
  AppIcon-Cyberpunk-Flat.svg  flattened master, squircle applied
  MenuBarIconTemplate.svg     14x18pt master, black + alpha
  MenuBarIconTemplate.png     14x18 and 28x36 raster fallbacks
  Alternates/                 cream, navy, and split-label versions
  generate.py                 rebuilds every derived file from source
```

## Palette

| Element | Colour |
| --- | --- |
| Background gradient | `#0A0120` → `#2A0755` → `#551180` |
| Sun ramp | `#FFE98A` → `#FFBE33` → `#FF7A2F` → `#D93B4A` → `#8E2FA8` → `#4A1580` |
| Bottle body | `#FF2D95` |
| Label plate | `#1F0543` (computed: background ramp at 1/3) |
| Cap and panes | `#A855F7` |

## The sun layer

The sun is banded, and each band is a flat fill sampled from a five-stop ramp at
that band's vertical position — there is no gradient inside any single band. The
steps are what make it read as retro rather than as a modern soft gradient, so
if you edit it, keep the fills flat.

The upper half is one solid shape carrying a smooth gradient across the first
half of the ramp. Stepping begins at the midline, where the bands open into
slits and shrink as they descend, continuing the ramp to its end. The ramp deliberately passes through red rather than coral on its way to violet.
A pink stop there sits at the same hue and brightness as the bottle body, and
the two fuse where they meet. Red separates cleanly, and the violet tail lets
the lowest bands sink into the background. If you retune `SUN_STOPS`, keep the
0.6 to 0.8 region out of the magenta family.

`USE_PLATE` at the top of `generate.py` toggles the dark plate behind the panes.
It is on. The accents sit two steps lighter than the plate, which is what keeps
the panes separate at dock sizes — `#551180` straight off the background ramp
was too close to the plate and the panes fused at 64pt. If you darken `NEON`,
re-check it small before shipping. When on, the plate is computed as
`ramp(BG_STOPS, 1/3)` so it tracks the background automatically. The layer
files renumber themselves either way.

Edit `SUN_STOPS` in `generate.py` to change the ramp; band geometry is driven by
`SUN_CY` and `SUN_R` directly below it.

## macOS 26 — Icon Composer

The layers in `IconComposer-Layers/` are deliberately **not** masked to a
squircle and carry no shadows or highlights. macOS applies the rounded-rect
shape and generates all the Liquid Glass lighting itself. Adding your own would
double it up.

The bottle and the sun share the canvas centre, so the margin above the cap
and below the body are identical. Keep them concentric if you rescale either.

Layers are numbered back to front and split by colour, which is what lets you
recolour one element for dark or tinted mode without touching the others.

Layer count depends on `USE_PLATE`: four layers plus background when on, three
when off.

1. Open Icon Composer (Xcode → Open Developer Tool → Icon Composer).
2. File → New, choose macOS.
3. Drag `0-Background.svg` onto the background slot.
4. Drag layers 1 through 4 in order. Icon Composer stacks them back to front.
5. Set materials per layer in the inspector. Start with the sun at low
   specularity, the bottle body at medium, and the neon accents high — the
   cyan is where the glass highlight should land.
6. Step through the Default, Dark, Clear and Tinted previews. The dark variant
   usually needs the background gradient darkened; everything else holds.
7. File → **Save** as `AppIcon.icon`. Do not use Export — that writes a flat PNG.
8. Drag `AppIcon.icon` into the Xcode project.

Because the Icon Composer file and the asset catalog set share the name
`AppIcon`, macOS 26 uses the layered version and older systems fall back to the
PNGs automatically. Keep both.

If the new icon does not appear on macOS 26, check that `CFBundleIconName` is
present in Info.plist and that you are building against the macOS 26 SDK.

## Menu bar usage

The glyph is 14 x 18, not square. A bottle is taller than it is wide, and padding
it into a square box makes it read smaller than the system glyphs beside it.
NSStatusItem handles non-square template images and adds its own padding.

The label is two bars rather than the app icon's four panes. Four panes merge
into a single dark block below about 20pt — the app icon has room for them and
the menu bar does not.

The imageset is flagged `template-rendering-intent: template`, so AppKit
discards the artwork colour and tints it to match the bar. Do not set a colour
yourself, and do not use the cyberpunk palette here — template images are
monochrome by definition.

```swift
let statusItem = NSStatusBar.system.statusItem(withLength: .variableLength)

if let button = statusItem.button {
    let image = NSImage(named: "MenuBarIconTemplate")
    image?.isTemplate = true
    image?.size = NSSize(width: 14, height: 18)
    button.image = image
    button.imagePosition = .imageOnly
}
```

If you load the PNG directly from the bundle rather than the catalog, keep the
`Template` suffix on the filename — AppKit sets `isTemplate` automatically for
any image name ending in `Template`.

## Standalone .icns

```
iconutil -c icns AppIcon.iconset
```

Needed for non-Xcode builds, DMG backgrounds, and Sparkle update packages.

## Regenerating

Edit the SVGs, then:

```
pip install cairosvg
python3 Sources/generate.py
```

Every layer PNG, flat PNG, the PDF, and all three `Contents.json` files are
rewritten from source. Nothing in the pack is hand-maintained.

Colours live at the top of `generate.py` as named constants, so a palette change
is five edits and one command.
