# Wallpaper Picker Plan

## Overview
A local-only wallpaper picker inspired by serpantinum's design, built as a QuickShell component. Opens as a full-screen overlay with a horizontal carousel of skewed thumbnail cards and color filter tabs.

## Architecture

### New Files
1. **`WallpaperPicker.qml`** — Main picker component (full-screen PanelWindow)
2. **`scripts/color_extract.py`** — Extracts dominant colors from wallpapers, assigns bucket categories, caches to JSON
3. **`scripts/wallpaper_apply.sh`** — Sets wallpaper via `awww img` + runs `matugen image` to regenerate colors.js

### Modified Files
4. **`shell.qml`** — Add wallpaper pill to bar + WallpaperPicker instance + open/close wiring

## Component Design

### WallpaperPicker.qml

**Window:** Full-screen `PanelWindow` with `WlrLayershell.layer: WlrLayer.Overlay`, transparent background, `ExclusionMode.Ignore`.

**Layout (top to bottom):**
```
┌──────────────────────────────────────────────────┐
│  Filter Bar (z:200, top center)                  │
│  [All] [🔴][🟠][🟡][🟢][🔵][🟣][🩷][⚪]       │
├──────────────────────────────────────────────────┤
│                                                   │
│  Horizontal Carousel (ListView, z:0)             │
│   [card] [card] [ SELECTED CARD ] [card] [card] │
│                                                   │
├──────────────────────────────────────────────────┤
│  Current wallpaper name (bottom center, z:200)   │
└──────────────────────────────────────────────────┘
```

**Carousel properties (matching serpantinum):**
- `itemWidth: 400`, `itemHeight: 420` (scaled)
- `skewFactor: -0.35` (Matrix4x4 horizontal shear)
- Selected card: `itemWidth * 1.5` wide, `itemHeight + 30` tall
- Side cards: `itemWidth * 0.48 * sideScale`, decay `0.88^dist`
- Highlight: `StrictlyEnforceRange`, `highlightMoveDuration: 400`
- Transitions: `NumberAnimation { properties: "x,y"; duration: 400; easing.type: Easing.OutCubic }`

**Delegate structure (inside out):**
1. Root `Item` — sized to cell, verticalCenter + offset
2. `skewedWrapper` — applies Matrix4x4 shear transform
3. `MouseArea` — click applies wallpaper
4. `paperContentFrame` — margins for border
5. `Rectangle` — background (`surface0` color), rounded corners
6. `Image` — thumbnail, counter-skewed via inverse Matrix4x4, `PreserveAspectCrop`
7. Filename label at bottom of card

**Filter tabs:**
- "All" button (grid icon drawn via Canvas or Nerd Font 󰝘)
- 8 color circles: Red `#FF4500`, Orange `#FFA500`, Yellow `#FFD700`, Green `#32CD32`, Blue `#1E90FF`, Purple `#8A2BE2`, Pink `#FF69B4`, Monochrome `#A9A9A9`
- Height: `34px`, rounded corners
- Active: `text` border, scale 1.05; Inactive: `surface1` border; Hover: scale 1.03

**Color assignment:** Each wallpaper is assigned to a bucket by its dominant color via `color_extract.py`. The bucket determines which color filter shows it.

**Keyboard shortcuts:**
- Left/Right: navigate carousel
- Enter: apply selected wallpaper
- Tab/Backtab: cycle filter
- Escape: close picker

**Data flow:**
1. `FolderListModel` watches `~/Pictures/Wallpapers/`
2. On change, runs `color_extract.py` which outputs JSON with `{fileName, dominantHex, bucket}`
3. QML reads cached JSON via `FileView`, populates `ListModel`
4. Filter tabs filter the model by bucket

### color_extract.py
- Input: wallpaper directory path, cache directory path
- Uses `colorthief` (or PIL fallback) to extract dominant color
- Maps dominant color to bucket (Red/Orange/Yellow/Green/Blue/Purple/Pink/Monochrome) using HSL hue ranges
- Output: JSON file at `~/.cache/quickshell/wallpaper/colors.json`:
  ```json
  [{"fileName": "wall.jpg", "hex": "#3a7cbd", "bucket": "Blue"}, ...]
  ```
- Also generates thumbnails at `~/.cache/quickshell/wallpaper/thumbs/` (400px wide JPEGs)

### wallpaper_apply.sh
- Input: wallpaper file path
- Runs: `awww img "<path>"` to set wallpaper
- Runs: `matugen image "<path>"` to regenerate colors.js + all app themes
- Optional: writes current wallpaper name to `~/.cache/quickshell/wallpaper/current.txt`

### shell.qml Integration
- New `Module` pill with icon `󰸉` (Nerd Font wallpaper icon) added to bar row
- `WallpaperPicker` component instantiated inside `ShellRoot`
- Pill click opens/closes the picker
- Picker closes on wallpaper apply

## Color Bucket Mapping (HSL hue ranges)
| Bucket | Hue Range |
|--------|-----------|
| Red | 345-15 |
| Orange | 15-45 |
| Yellow | 45-70 |
| Green | 70-160 |
| Blue | 160-260 |
| Purple | 260-300 |
| Pink | 300-345 |
| Monochrome | saturation < 15% |

## Implementation Order
1. `scripts/color_extract.py` — color extraction + thumbnail generation
2. `scripts/wallpaper_apply.sh` — wallpaper apply script
3. `WallpaperPicker.qml` — the full picker UI
4. `shell.qml` modifications — add pill + picker instance
