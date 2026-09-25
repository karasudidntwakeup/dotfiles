#!/usr/bin/env bash
# Apply a wallpaper with full matugen customization — Drop-in replacement
# for ~/.config/rofi/wallpaper-changer/launcher.sh.
#
# usage:
#   wallpaper_apply.sh <image_path> [ignored] <scheme> [hex]=RRGGBB [pin_widgets=0|1]
#
# Single mode, derived from the scheme: light schemes -> light system
# (matugen --prefer lightness + QuickShell qs-theme.json + system GTK/icons),
# dark schemes -> dark system. The old manual dark|light arg is ignored.
# scheme: tonal_spot|content|fidelity|vibrant|neutral|monochrome|rainbow
#         (fixed presets) serpantinum|catppuccin_frappe|catppuccin_macchiato|catppuccin_latte|
#         nord|tokyo|dracula|gruvbox|rosepine|kanagawa
#         bw|blackwhite|black_white        (pure black & white monochrome)
#         wallpaper_color                            (from a chosen hex)
#   wallpaper_color requires a 4th arg: the RGB hex to generate from.

set -e

IMG="$1"
# One mode: $2 (old manual dark|light) is ignored — light/dark is derived
# from the scheme itself below (derive_mode_from_scheme).
MODE_OVERRIDE="$2"
SCHEME="${3:-}"
HEX="${4:-}"
PIN_WIDGETS="${5:-0}"

QUICK_THEME_FILE="$HOME/.config/quickshell/qs-theme.json"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/quickshell/wallpaper"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXTRA_PALETTES="$SCRIPT_DIR/nvim_themes.json"
mkdir -p "$CACHE"

[ -f "$IMG" ] || { echo "wallpaper_apply: not found: $IMG" >&2; exit 1; }

if [ -z "$SCHEME" ] && [ -f "$CACHE/scheme.txt" ]; then
  mapfile -t SAVED_SCHEME < "$CACHE/scheme.txt"
  SCHEME="${SAVED_SCHEME[0]:-}"
  HEX="${SAVED_SCHEME[1]:-}"
fi
SCHEME="${SCHEME:-tonal_spot}"

# MODE/PREFER/QUICK are set by derive_mode_from_scheme() after the scheme
# resolves (light schemes -> light system, dark schemes -> dark system).

# Build a full Material-3 palette from a serpantinum/(Catppuccin) preset and
# feed it to `matugen json`, mirroring how serpantinum maps their palette to
# MD3 roles.
apply_preset() {
  local flavor="$1"
  local out="$CACHE/palette_${flavor}.json"
  python3 - "$flavor" "$out" "$EXTRA_PALETTES" <<'PY'
import json, sys
flavor, out, extra = sys.argv[1:4]

p = {
  # serpantinum default = Catppuccin Mocha
  "mocha": {
    "base": "#1e1e2e", "mantle": "#181825", "crust": "#11111b",
    "surface0": "#313244", "surface1": "#45475a", "surface2": "#585b70",
    "overlay0": "#6c7086", "overlay1": "#7f849c", "overlay2": "#9399b2",
    "text": "#cdd6f4", "subtext0": "#a6adc8", "subtext1": "#bac2de",
    "blue": "#89b4fa", "sapphire": "#74c7ec", "peach": "#fab387",
    "green": "#a6e3a1", "red": "#f38ba8", "mauve": "#cba6f7",
    "pink": "#f5c2e7", "yellow": "#f9e2af", "maroon": "#eba0ac",
  },
  "bw": {
    "base": "#000000", "mantle": "#000000", "crust": "#000000",
    "surface0": "#000000", "surface1": "#ffffff", "surface2": "#ffffff",
    "overlay0": "#000000", "overlay1": "#ffffff", "overlay2": "#ffffff",
    "text": "#ffffff", "subtext0": "#ffffff", "subtext1": "#ffffff",
    "blue": "#ffffff", "sapphire": "#ffffff", "peach": "#ffffff",
    "green": "#ffffff", "red": "#ffffff", "mauve": "#ffffff",
    "pink": "#ffffff", "yellow": "#ffffff", "maroon": "#ffffff",
  },
  "frappe": {
    "base": "#303446", "mantle": "#292c3c", "crust": "#232634",
    "surface0": "#414559", "surface1": "#51576d", "surface2": "#626880",
    "overlay0": "#737994", "overlay1": "#838ba7", "overlay2": "#949cbb",
    "text": "#c6d0f5", "subtext0": "#a5adce", "subtext1": "#b5bfe2",
    "blue": "#8caaee", "sapphire": "#85c1dc", "peach": "#ef9f76",
    "green": "#a6d189", "red": "#e78284", "mauve": "#ca9ee6",
    "pink": "#f4b8e4", "yellow": "#e5c890", "maroon": "#ea999c",
  },
  "latte": {
    "base": "#eff1f5", "mantle": "#e6e9ef", "crust": "#dce0e8",
    "surface0": "#ccd0da", "surface1": "#bcc0cc", "surface2": "#acb0be",
    "overlay0": "#6c6f85", "overlay1": "#5c5f77", "overlay2": "#4c4f69",
    "text": "#4c4f69", "subtext0": "#6c6f85", "subtext1": "#5c5f77",
    "blue": "#1e66f5", "sapphire": "#209fb5", "peach": "#fe640b",
    "green": "#40a02b", "red": "#d20f39", "mauve": "#8839ef",
    "pink": "#ea76cb", "yellow": "#df8e1d", "maroon": "#e64553",
  },
  "macchiato": {
    "base": "#24273a", "mantle": "#1e2030", "crust": "#181926",
    "surface0": "#363a4f", "surface1": "#494d64", "surface2": "#5b6078",
    "overlay0": "#6e738d", "overlay1": "#8087a2", "overlay2": "#939ab7",
    "text": "#cad3f5", "subtext0": "#a5adcb", "subtext1": "#b8c0e0",
    "blue": "#8aadf4", "sapphire": "#7dc4e4", "peach": "#f5a97f",
    "green": "#a6da95", "red": "#ed8796", "mauve": "#c6a0f6",
    "pink": "#f5b8e4", "yellow": "#eed49f", "maroon": "#ee99a0",
  },
  "nord": {
    "base": "#2e3440", "mantle": "#262b36", "crust": "#1e232c",
    "surface0": "#363c49", "surface1": "#3d4452", "surface2": "#434c5e",
    "overlay0": "#4c566a", "overlay1": "#5a6680", "overlay2": "#6b7894",
    "text": "#d8dee9", "subtext0": "#b6c0d4", "subtext1": "#c4ccdd",
    "blue": "#5e81ac", "sapphire": "#88c0d0", "peach": "#d08770",
    "green": "#a3be8c", "red": "#bf616a", "mauve": "#b48ead",
    "pink": "#b48ead", "yellow": "#ebcb8b", "maroon": "#a64b55",
  },
  "tokyo": {
    "base": "#24283b", "mantle": "#1e2233", "crust": "#16161e",
    "surface0": "#292e42", "surface1": "#2f3549", "surface2": "#3d4157",
    "overlay0": "#4b526d", "overlay1": "#565f89", "overlay2": "#6a71a0",
    "text": "#c0caf5", "subtext0": "#a9b1d6", "subtext1": "#bac2e8",
    "blue": "#7aa2f7", "sapphire": "#7dcfff", "peach": "#ff9e64",
    "green": "#9ece6a", "red": "#f7768e", "mauve": "#bb9af7",
    "pink": "#d3869b", "yellow": "#e0af68", "maroon": "#db4b4b",
  },
  "dracula": {
    "base": "#282a36", "mantle": "#21222c", "crust": "#191a21",
    "surface0": "#343746", "surface1": "#3d404f", "surface2": "#44475a",
    "overlay0": "#52576b", "overlay1": "#6272a4", "overlay2": "#7079b0",
    "text": "#f8f8f2", "subtext0": "#cfd2e0", "subtext1": "#a9adc5",
    "blue": "#8be9fd", "sapphire": "#8be9fd", "peach": "#ffb86c",
    "green": "#50fa7b", "red": "#ff5555", "mauve": "#bd93f9",
    "pink": "#ff79c6", "yellow": "#f1fa8c", "maroon": "#ff6e5e",
  },
  "gruvbox": {
    "base": "#282828", "mantle": "#1f2021", "crust": "#1d2021",
    "surface0": "#32302f", "surface1": "#3c3836", "surface2": "#504945",
    "overlay0": "#665c54", "overlay1": "#7c6f64", "overlay2": "#928374",
    "text": "#ebdbb2", "subtext0": "#d5c4a1", "subtext1": "#bdae93",
    "blue": "#83a598", "sapphire": "#8ec07c", "peach": "#fe8019",
    "green": "#b8bb26", "red": "#fb4934", "mauve": "#d3869b",
    "pink": "#b16286", "yellow": "#fabd2f", "maroon": "#cc241d",
  },
  "rosepine": {
    "base": "#191724", "mantle": "#15131d", "crust": "#121019",
    "surface0": "#1f1d2e", "surface1": "#26233a", "surface2": "#2e2a45",
    "overlay0": "#6e6a86", "overlay1": "#908caa", "overlay2": "#9c98b8",
    "text": "#e0def4", "subtext0": "#c6c2e2", "subtext1": "#908caa",
    "blue": "#c4a7e7", "sapphire": "#9ccfd8", "peach": "#f6c177",
    "green": "#95d1b6", "red": "#eb6f92", "mauve": "#c4a7e7",
    "pink": "#ebbcba", "yellow": "#f6c177", "maroon": "#d7827e",
  },
  "kanagawa": {
    "base": "#1f1f28", "mantle": "#1a1a22", "crust": "#16161d",
    "surface0": "#2b2b38", "surface1": "#363646", "surface2": "#424256",
    "overlay0": "#54546d", "overlay1": "#727169", "overlay2": "#7f7f8f",
    "text": "#dcd7ba", "subtext0": "#c2bda0", "subtext1": "#a6a189",
    "blue": "#7e9cd8", "sapphire": "#7aa89f", "peach": "#ffa066",
    "green": "#76946a", "red": "#c34043", "mauve": "#957fb8",
    "pink": "#b1a6d0", "yellow": "#c0a36e", "maroon": "#c3464e",
  },
  "everforest": {
    "base": "#2d353b", "mantle": "#272f34", "crust": "#22292e",
    "surface0": "#343f44", "surface1": "#3d484d", "surface2": "#475258",
    "overlay0": "#6a747c", "overlay1": "#7a8478", "overlay2": "#859289",
    "text": "#d3c6aa", "subtext0": "#c0c5b0", "subtext1": "#a5ac97",
    "blue": "#7fbbb3", "sapphire": "#83c092", "peach": "#e69875",
    "green": "#a7c080", "red": "#e67e80", "mauve": "#d699b6",
    "pink": "#d699b6", "yellow": "#dbbc7f", "maroon": "#e67e80",
  },
  "solarized": {
    "base": "#002b36", "mantle": "#00232d", "crust": "#001a21",
    "surface0": "#073642", "surface1": "#0b4250", "surface2": "#104e5d",
    "overlay0": "#586e75", "overlay1": "#657b83", "overlay2": "#7b8797",
    "text": "#93a1a1", "subtext0": "#839496", "subtext1": "#586e75",
    "blue": "#268bd2", "sapphire": "#2aa198", "peach": "#cb4b16",
    "green": "#859900", "red": "#dc322f", "mauve": "#6c71c4",
    "pink": "#d33682", "yellow": "#b58900", "maroon": "#dc322f",
  },
  "onedark": {
    "base": "#282c34", "mantle": "#23272e", "crust": "#1e2229",
    "surface0": "#2c313a", "surface1": "#31363f", "surface2": "#3b4049",
    "overlay0": "#4b5263", "overlay1": "#565f6e", "overlay2": "#677080",
    "text": "#abb2bf", "subtext0": "#8f96a3", "subtext1": "#7d8490",
    "blue": "#61afef", "sapphire": "#56b6c2", "peach": "#d19a66",
    "green": "#98c379", "red": "#e06c75", "mauve": "#c678dd",
    "pink": "#d05f8e", "yellow": "#e5c07b", "maroon": "#be5046",
  },
  "ayu": {
    "base": "#0b0e14", "mantle": "#090b10", "crust": "#07080d",
    "surface0": "#0d1017", "surface1": "#11151d", "surface2": "#161b24",
    "overlay0": "#626a73", "overlay1": "#6e7780", "overlay2": "#7a838d",
    "text": "#b3b1ad", "subtext0": "#8a9199", "subtext1": "#6a7077",
    "blue": "#59c2ff", "sapphire": "#95e6cb", "peach": "#ff8f40",
    "green": "#aad94c", "red": "#f07178", "mauve": "#d2a6ff",
    "pink": "#d2a6ff", "yellow": "#ffb454", "maroon": "#e0556d",
  },
  "horizon": {
    "base": "#1c1e26", "mantle": "#171820", "crust": "#13141a",
    "surface0": "#232530", "surface1": "#2a2c36", "surface2": "#31333e",
    "overlay0": "#565a64", "overlay1": "#6a6a7a", "overlay2": "#7b7f8b",
    "text": "#d5d8da", "subtext0": "#a9adb8", "subtext1": "#8b8f9b",
    "blue": "#26bbd9", "sapphire": "#59e3e3", "peach": "#f09483",
    "green": "#29d398", "red": "#e95678", "mauve": "#ee64ac",
    "pink": "#ee64ac", "yellow": "#fab795", "maroon": "#dd4a66",
  },
  "nightowl": {
    "base": "#011627", "mantle": "#01111f", "crust": "#010c17",
    "surface0": "#0b1f33", "surface1": "#14283d", "surface2": "#1d3045",
    "overlay0": "#465a70", "overlay1": "#556b83", "overlay2": "#6b83a3",
    "text": "#d6deeb", "subtext0": "#b3c0d4", "subtext1": "#91a0b8",
    "blue": "#82aaff", "sapphire": "#7fdbca", "peach": "#f78c6c",
    "green": "#addb67", "red": "#ef5350", "mauve": "#c792ea",
    "pink": "#c792ea", "yellow": "#ffeb95", "maroon": "#d4433f",
  },
  "material": {
    "base": "#263238", "mantle": "#20272b", "crust": "#1a2024",
    "surface0": "#2c3439", "surface1": "#333d43", "surface2": "#3b464c",
    "overlay0": "#546e7a", "overlay1": "#6a828f", "overlay2": "#7d93af",
    "text": "#eceff1", "subtext0": "#b0bec5", "subtext1": "#90a4ae",
    "blue": "#1e88e5", "sapphire": "#00acc1", "peach": "#f4511e",
    "green": "#43a047", "red": "#e53935", "mauve": "#7e57c2",
    "pink": "#d81b60", "yellow": "#fdd835", "maroon": "#c62828",
  },
  "monokai": {
    "base": "#272822", "mantle": "#23241f", "crust": "#1d1e1a",
    "surface0": "#2f2f2a", "surface1": "#383830", "surface2": "#41413a",
    "overlay0": "#5a5a52", "overlay1": "#75715e", "overlay2": "#8b8871",
    "text": "#f8f8f2", "subtext0": "#cfcfc2", "subtext1": "#a7a798",
    "blue": "#66d9ef", "sapphire": "#a1efe4", "peach": "#fd971f",
    "green": "#a6e22e", "red": "#f92672", "mauve": "#ae81ff",
    "pink": "#ae81ff", "yellow": "#e6db74", "maroon": "#e03b6f",
  },
  "palenight": {
    "base": "#292d3e", "mantle": "#242837", "crust": "#1e2230",
    "surface0": "#2e3347", "surface1": "#383d54", "surface2": "#434a63",
    "overlay0": "#5d668a", "overlay1": "#676e95", "overlay2": "#7b81a8",
    "text": "#bfc7d5", "subtext0": "#a5adc8", "subtext1": "#8d95ae",
    "blue": "#82aaff", "sapphire": "#89ddff", "peach": "#f78c6c",
    "green": "#c3e88d", "red": "#f07178", "mauve": "#c792ea",
    "pink": "#c792ea", "yellow": "#ffcb6b", "maroon": "#e2585f",
  },
  "oceanic": {
    "base": "#1b2b34", "mantle": "#16242c", "crust": "#121e26",
    "surface0": "#223440", "surface1": "#2a3e4a", "surface2": "#334a58",
    "overlay0": "#4f5c66", "overlay1": "#65737e", "overlay2": "#7c8890",
    "text": "#c0c5ce", "subtext0": "#a5acb8", "subtext1": "#8a919d",
    "blue": "#6699cc", "sapphire": "#5fb3b3", "peach": "#f99157",
    "green": "#99c794", "red": "#ec5f67", "mauve": "#c594c5",
    "pink": "#c594c5", "yellow": "#fac863", "maroon": "#d94f57",
  },
  "snazzy": {
    "base": "#282a36", "mantle": "#232530", "crust": "#1e202b",
    "surface0": "#303240", "surface1": "#383a4a", "surface2": "#414354",
    "overlay0": "#5a5f6f", "overlay1": "#777c89", "overlay2": "#96979e",
    "text": "#eff0eb", "subtext0": "#cfd2ce", "subtext1": "#a6a8a3",
    "blue": "#57c7ff", "sapphire": "#9aedfe", "peach": "#ff9f43",
    "green": "#5af78e", "red": "#ff5c57", "mauve": "#ff6ac1",
    "pink": "#ff6ac1", "yellow": "#f3f99d", "maroon": "#e34f4a",
  },
  "github_dark": {
    "base": "#0d1117", "mantle": "#0a0e12", "crust": "#06090d",
    "surface0": "#161b22", "surface1": "#21262d", "surface2": "#30363d",
    "overlay0": "#484f58", "overlay1": "#8b949e", "overlay2": "#9aa4ad",
    "text": "#e6edf3", "subtext0": "#c2c8d1", "subtext1": "#9ba6b0",
    "blue": "#58a6ff", "sapphire": "#39c5cf", "peach": "#f0883e",
    "green": "#3fb950", "red": "#ff7b72", "mauve": "#bc8cff",
    "pink": "#d2a8ff", "yellow": "#d29922", "maroon": "#e5534b",
  },
  "nightfox": {
    "base": "#192330", "mantle": "#151e29", "crust": "#111923",
    "surface0": "#1d2839", "surface1": "#23304a", "surface2": "#2a3854",
    "overlay0": "#3f4c5f", "overlay1": "#4e5a6e", "overlay2": "#5f6c80",
    "text": "#cdcecf", "subtext0": "#aeb3ba", "subtext1": "#8f97a3",
    "blue": "#719cd6", "sapphire": "#78c2b3", "peach": "#e59866",
    "green": "#81b29a", "red": "#d16983", "mauve": "#9d79d6",
    "pink": "#d67ad2", "yellow": "#dbc074", "maroon": "#bb5669",
  },
  "rosepine_moon": {
    "base": "#232136", "mantle": "#1e1d31", "crust": "#191828",
    "surface0": "#2a273f", "surface1": "#393552", "surface2": "#403d5b",
    "overlay0": "#6e6a86", "overlay1": "#908caa", "overlay2": "#a7a3c2",
    "text": "#e0def4", "subtext0": "#c7c3e6", "subtext1": "#9b97b8",
    "blue": "#c4a7e7", "sapphire": "#9ccfd8", "peach": "#f6c177",
    "green": "#86d4c8", "red": "#eb6f92", "mauve": "#c4a7e7",
    "pink": "#ebbcba", "yellow": "#f6c177", "maroon": "#d7827e",
  },
  "rosepine_dawn": {
    "base": "#faf4ed", "mantle": "#f3ecdf", "crust": "#eee5d7",
    "surface0": "#f2e9de", "surface1": "#dfdad9", "surface2": "#cecacd",
    "overlay0": "#6e6a86", "overlay1": "#908caa", "overlay2": "#9899a1",
    "text": "#575279", "subtext0": "#6e6a86", "subtext1": "#8a869d",
    "blue": "#56949f", "sapphire": "#286983", "peach": "#ea9d34",
    "green": "#6e9e6c", "red": "#b4637a", "mauve": "#907aa9",
    "pink": "#d7827e", "yellow": "#ea9d34", "maroon": "#b4637a",
  },
  "zenburn": {
    "base": "#383838", "mantle": "#333333", "crust": "#2d2d2d",
    "surface0": "#404040", "surface1": "#4a4a4a", "surface2": "#545454",
    "overlay0": "#6b6b6b", "overlay1": "#8f8f8f", "overlay2": "#9f9f9f",
    "text": "#dcdccc", "subtext0": "#b8b8a8", "subtext1": "#9f9f8f",
    "blue": "#8cd0d3", "sapphire": "#a8c0c8", "peach": "#dfaf8f",
    "green": "#7f9f7f", "red": "#cc9393", "mauve": "#dfaf8f",
    "pink": "#dfaf8f", "yellow": "#f0dfaf", "maroon": "#b37575",
  },
  "synthwave": {
    "base": "#262335", "mantle": "#211e2e", "crust": "#1b1926",
    "surface0": "#2e2a40", "surface1": "#37334b", "surface2": "#404059",
    "overlay0": "#4c466a", "overlay1": "#5f5675", "overlay2": "#74688f",
    "text": "#f4eee4", "subtext0": "#d9cde8", "subtext1": "#b8aacf",
    "blue": "#36f9f6", "sapphire": "#36f9f6", "peach": "#ff8b39",
    "green": "#72f1b8", "red": "#fe4450", "mauve": "#f92aad",
    "pink": "#f97e72", "yellow": "#fede5d", "maroon": "#e23a46",
  },
  "doom": {
    "base": "#282c34", "mantle": "#23272e", "crust": "#1d2128",
    "surface0": "#303541", "surface1": "#383f4d", "surface2": "#41495a",
    "overlay0": "#4f586b", "overlay1": "#5f6a7e", "overlay2": "#737e92",
    "text": "#bbc2cf", "subtext0": "#a2aab8", "subtext1": "#8d94a3",
    "blue": "#51afef", "sapphire": "#56b6c2", "peach": "#da8548",
    "green": "#98be65", "red": "#ff6c6b", "mauve": "#c678dd",
    "pink": "#c678dd", "yellow": "#ecbe7b", "maroon": "#e05a55",
  },
  "vscode_dark": {
    "base": "#1e1e1e", "mantle": "#1a1a1a", "crust": "#161616",
    "surface0": "#252526", "surface1": "#2d2d30", "surface2": "#3c3c3c",
    "overlay0": "#424242", "overlay1": "#5a5a5a", "overlay2": "#6e6e6e",
    "text": "#d4d4d4", "subtext0": "#b5b5b5", "subtext1": "#949494",
    "blue": "#569cd6", "sapphire": "#4ec9b0", "peach": "#ce9178",
    "green": "#6a9955", "red": "#f14c4c", "mauve": "#c586c0",
    "pink": "#d16969", "yellow": "#dcdcaa", "maroon": "#e04a4a",
  },
  "moonfly": {
    "base": "#080808", "mantle": "#060606", "crust": "#040404",
    "surface0": "#101010", "surface1": "#1a1a1a", "surface2": "#222222",
    "overlay0": "#383838", "overlay1": "#484848", "overlay2": "#585858",
    "text": "#b2b2b2", "subtext0": "#909090", "subtext1": "#707070",
    "blue": "#80a0ff", "sapphire": "#79dac8", "peach": "#ff8a80",
    "green": "#8cc85f", "red": "#ff5454", "mauve": "#cf87e8",
    "pink": "#ff5189", "yellow": "#e3c78a", "maroon": "#d94343",
  },
  "cobalt": {
    "base": "#193549", "mantle": "#162f41", "crust": "#122737",
    "surface0": "#1f4259", "surface1": "#254b64", "surface2": "#2b566e",
    "overlay0": "#3e6f8c", "overlay1": "#47718c", "overlay2": "#55839f",
    "text": "#ffffff", "subtext0": "#d9e6f0", "subtext1": "#a8c6d8",
    "blue": "#0088ff", "sapphire": "#9effff", "peach": "#ff9d00",
    "green": "#3ad900", "red": "#ff628c", "mauve": "#e5a0ff",
    "pink": "#ff628c", "yellow": "#ffc600", "maroon": "#e24d70",
  },
  "nothing": {
    "base": "#0b0b0d", "mantle": "#08080a", "crust": "#050506",
    "surface0": "#141417", "surface1": "#1d1d21", "surface2": "#26262c",
    "overlay0": "#3c3c44", "overlay1": "#6e6e78", "overlay2": "#8f8f9a",
    "text": "#f4f4f2", "subtext0": "#b6b6bc", "subtext1": "#8a8a94",
    "blue": "#d71920", "sapphire": "#ff5a52", "peach": "#f4f4f2",
    "green": "#8f8f9a", "red": "#d71920", "mauve": "#c9c9cf",
    "pink": "#f4f4f2", "yellow": "#b6b6bc", "maroon": "#7a1210",
  },
  "wombat": {
    "base": "#242424", "mantle": "#1e1e1e", "crust": "#1a1a1a",
    "surface0": "#2b2b2b", "surface1": "#333333", "surface2": "#3d3d3d",
    "overlay0": "#585858", "overlay1": "#6a6a6a", "overlay2": "#7a7a7a",
    "text": "#f6f3e8", "subtext0": "#d5d2c6", "subtext1": "#aaa79a",
    "blue": "#8ac6f2", "sapphire": "#8ac6f2", "peach": "#f99157",
    "green": "#95e454", "red": "#e5786d", "mauve": "#9999cc",
    "pink": "#9999cc", "yellow": "#cae682", "maroon": "#cf5f54",
  },
  "shades_of_purple": {
    "base": "#1e1e3f", "mantle": "#1a1a39", "crust": "#161633",
    "surface0": "#262650", "surface1": "#2d2d59", "surface2": "#343464",
    "overlay0": "#4b4b7f", "overlay1": "#5f5f99", "overlay2": "#7171ae",
    "text": "#f0e6d0", "subtext0": "#cfc6ae", "subtext1": "#a89f8a",
    "blue": "#a599e9", "sapphire": "#9ff0e2", "peach": "#ff9d00",
    "green": "#5ff1b7", "red": "#ff628c", "mauve": "#d3a5ff",
    "pink": "#ff7fd6", "yellow": "#ffc94d", "maroon": "#e2556f",
  },
  "solarized_light": {
    "base": "#fdf6e3", "mantle": "#f4eccb", "crust": "#ece4c7",
    "surface0": "#eee8d5", "surface1": "#e4dcc3", "surface2": "#d8d0b8",
    "overlay0": "#93a1a1", "overlay1": "#839496", "overlay2": "#657b83",
    "text": "#586e75", "subtext0": "#657b83", "subtext1": "#93a1a1",
    "blue": "#268bd2", "sapphire": "#2aa198", "peach": "#cb4b16",
    "green": "#859900", "red": "#dc322f", "mauve": "#6c71c4",
    "pink": "#d33682", "yellow": "#b58900", "maroon": "#dc322f",
  },
  "gruvbox_light": {
    "base": "#fbf1c7", "mantle": "#f0e6b8", "crust": "#e6d9a5",
    "surface0": "#f0e7c2", "surface1": "#ebdbb2", "surface2": "#d5c4a1",
    "overlay0": "#bdae93", "overlay1": "#a89984", "overlay2": "#928374",
    "text": "#3c3836", "subtext0": "#504945", "subtext1": "#665c54",
    "blue": "#458588", "sapphire": "#689d6a", "peach": "#d65d0e",
    "green": "#98971a", "red": "#cc241d", "mauve": "#b16286",
    "pink": "#d3869b", "yellow": "#d79921", "maroon": "#9d0006",
  },
  "tokyoday": {
    "base": "#e1e2e7", "mantle": "#d5d7de", "crust": "#c8cbd4",
    "surface0": "#dfe0e6", "surface1": "#d4d6dd", "surface2": "#c6c9d2",
    "overlay0": "#9aa5b4", "overlay1": "#8b94a8", "overlay2": "#7e88a0",
    "text": "#3d4653", "subtext0": "#5a6a7a", "subtext1": "#7b8998",
    "blue": "#2e7de9", "sapphire": "#1b6b93", "peach": "#b15c00",
    "green": "#587539", "red": "#f52a65", "mauve": "#9854f1",
    "pink": "#b65ce0", "yellow": "#8c6c3e", "maroon": "#d5224d",
  },
  "everforest_light": {
    "base": "#fdf6e3", "mantle": "#f6eed2", "crust": "#efe7c8",
    "surface0": "#f6eeda", "surface1": "#ece5d0", "surface2": "#e0d9bf",
    "overlay0": "#a9b19a", "overlay1": "#8a9484", "overlay2": "#7a8475",
    "text": "#5c6a72", "subtext0": "#829181", "subtext1": "#687a6e",
    "blue": "#3a94c5", "sapphire": "#35a77c", "peach": "#f57d26",
    "green": "#83a43c", "red": "#f85552", "mauve": "#df69ba",
    "pink": "#df69ba", "yellow": "#dfa000", "maroon": "#e0453a",
  },
  # ---- Omarchy community themes (https://omarchy.org/themes) ----
  # Colors from each theme's upstream repo; surfaces derived from
  # bg/fg, accents mapped from ANSI. Skipped: dracula, monokai,
  # solarized, solarized_light (same as built-ins), monochrome
  # (covered by Auto scheme), gruvu (repo gone).
  "aetheria": {
    "base": "#0e091d", "mantle": "#000000", "crust": "#0b0717",
    "surface0": "#0e1729", "surface1": "#0f2232", "surface2": "#0f2e3d",
    "overlay0": "#c53253", "overlay1": "#756f7f", "overlay2": "#40979c",
    "text": "#14b9b5", "subtext0": "#a60234", "subtext1": "#756f7f",
    "blue": "#be3f50", "sapphire": "#ff7f41", "peach": "#fd3e6a",
    "green": "#c8e967", "red": "#e20342", "mauve": "#9147a8",
    "pink": "#6c032c", "yellow": "#7cd699", "maroon": "#ce4f48",
  },
  "ayaka": {
    "base": "#000000", "mantle": "#262626", "crust": "#000000",
    "surface0": "#121212", "surface1": "#202020", "surface2": "#303030",
    "overlay0": "#404040", "overlay1": "#8b8b8b", "overlay2": "#bcbcbc",
    "text": "#e6e6e6", "subtext0": "#f2f2f2", "subtext1": "#8b8b8b",
    "blue": "#6699ff", "sapphire": "#66cccc", "peach": "#ffdd80",
    "green": "#66cc66", "red": "#e65c5c", "mauve": "#cc66cc",
    "pink": "#e680e6", "yellow": "#ffcc66", "maroon": "#ff6666",
  },
  "black_gold": {
    "base": "#0d0d0d", "mantle": "#0c0c0c", "crust": "#0a0a0a",
    "surface0": "#1e1e1d", "surface1": "#2b2a2a", "surface2": "#393938",
    "overlay0": "#322f3b", "overlay1": "#807e83", "overlay2": "#b4b3b3",
    "text": "#e0dfdb", "subtext0": "#aa6c39", "subtext1": "#807e83",
    "blue": "#faeec8", "sapphire": "#e0dfdb", "peach": "#ccba78",
    "green": "#f5bf03", "red": "#d35f5f", "mauve": "#d4af37",
    "pink": "#d4af37", "yellow": "#ccba78", "maroon": "#d35f5f",
  },
  "felix": {
    "base": "#000000", "mantle": "#000000", "crust": "#000000",
    "surface0": "#121313", "surface1": "#202121", "surface2": "#313131",
    "overlay0": "#626262", "overlay1": "#9e9f9f", "overlay2": "#c6c7c8",
    "text": "#e7e9ea", "subtext0": "#e7e9ea", "subtext1": "#9e9f9f",
    "blue": "#626262", "sapphire": "#767676", "peach": "#b2b2b2",
    "green": "#e7e9ea", "red": "#8a8a8a", "mauve": "#8a8a8a",
    "pink": "#8a8a8a", "yellow": "#9e9e9e", "maroon": "#9e9e9e",
  },
  "harbor_dark": {
    "base": "#1b1b1b", "mantle": "#191919", "crust": "#161616",
    "surface0": "#2c2c2a", "surface1": "#393836", "surface2": "#484744",
    "overlay0": "#817f68", "overlay1": "#b2b09c", "overlay2": "#d4d0bf",
    "text": "#efebdc", "subtext0": "#e1ce98", "subtext1": "#b2b09c",
    "blue": "#e58980", "sapphire": "#6d6d6d", "peach": "#a99b7a",
    "green": "#e75a50", "red": "#f44336", "mauve": "#77838a",
    "pink": "#9ba2a6", "yellow": "#a99b7a", "maroon": "#e75a50",
  },
  "hermarchy": {
    "base": "#08090a", "mantle": "#070809", "crust": "#060708",
    "surface0": "#1b1c1c", "surface1": "#29292a", "surface2": "#393a39",
    "overlay0": "#606468", "overlay1": "#a1a3a3", "overlay2": "#cdcecb",
    "text": "#f1f1ec", "subtext0": "#d5d5d0", "subtext1": "#a1a3a3",
    "blue": "#74a8c7", "sapphire": "#61d6ff", "peach": "#ecd69a",
    "green": "#86d993", "red": "#e46e6e", "mauve": "#b7a1c7",
    "pink": "#cebdda", "yellow": "#e2c275", "maroon": "#f08a8a",
  },
  "mars": {
    "base": "#000000", "mantle": "#000000", "crust": "#000000",
    "surface0": "#110e0d", "surface1": "#1e1917", "surface2": "#2e2523",
    "overlay0": "#4a2c2c", "overlay1": "#8a6763", "overlay2": "#b58e88",
    "text": "#d9afa7", "subtext0": "#d9afa7", "subtext1": "#8a6763",
    "blue": "#7b534e", "sapphire": "#7b534e", "peach": "#e07b5f",
    "green": "#7b534e", "red": "#e07b5f", "mauve": "#a0392f",
    "pink": "#c45a3f", "yellow": "#c45a3f", "maroon": "#ff6b4a",
  },
  "mechanoonna": {
    "base": "#1c1b19", "mantle": "#1a1917", "crust": "#161614",
    "surface0": "#2d2b27", "surface1": "#3a3731", "surface2": "#49453d",
    "overlay0": "#6b655c", "overlay1": "#a79e8b", "overlay2": "#cfc4ab",
    "text": "#f0e4c5", "subtext0": "#fbf1c7", "subtext1": "#a79e8b",
    "blue": "#908d88", "sapphire": "#d4bd99", "peach": "#f7df97",
    "green": "#a89984", "red": "#c5564a", "mauve": "#afa499",
    "pink": "#cbae8e", "yellow": "#ebdbb2", "maroon": "#d94e38",
  },
  "one_dark_pro": {
    "base": "#282c34", "mantle": "#252830", "crust": "#20232a",
    "surface0": "#32373f", "surface1": "#3a3f47", "surface2": "#444851",
    "overlay0": "#5c6370", "overlay1": "#808794", "overlay2": "#979eab",
    "text": "#abb2bf", "subtext0": "#c8ccd4", "subtext1": "#808794",
    "blue": "#61afef", "sapphire": "#56b6c2", "peach": "#e5c07b",
    "green": "#98c379", "red": "#e06c75", "mauve": "#c678dd",
    "pink": "#c678dd", "yellow": "#e5c07b", "maroon": "#e06c75",
  },
  "rainy_night": {
    "base": "#1e1e2e", "mantle": "#45475a", "crust": "#181825",
    "surface0": "#2c2d3e", "surface1": "#36384a", "surface2": "#434558",
    "overlay0": "#585b70", "overlay1": "#8d92ab", "overlay2": "#b0b7d3",
    "text": "#cdd6f4", "subtext0": "#bac2de", "subtext1": "#8d92ab",
    "blue": "#89b4fa", "sapphire": "#94e2d5", "peach": "#f9e2af",
    "green": "#a6e3a1", "red": "#f38ba8", "mauve": "#cba6f7",
    "pink": "#cba6f7", "yellow": "#f9e2af", "maroon": "#f38ba8",
  },
  "retropc": {
    "base": "#0a0a08", "mantle": "#2a1f00", "crust": "#080806",
    "surface0": "#1e1707", "surface1": "#2c2107", "surface2": "#3d2d06",
    "overlay0": "#805500", "overlay1": "#b97e00", "overlay2": "#df9900",
    "text": "#ffb000", "subtext0": "#d4aa00", "subtext1": "#b97e00",
    "blue": "#cc9900", "sapphire": "#cc9900", "peach": "#ffdd00",
    "green": "#ffcc00", "red": "#ff8800", "mauve": "#ff9900",
    "pink": "#ffaa00", "yellow": "#ffd700", "maroon": "#ffaa00",
  },
  "void": {
    "base": "#05010c", "mantle": "#382952", "crust": "#04010a",
    "surface0": "#19151f", "surface1": "#28252e", "surface2": "#3a363f",
    "overlay0": "#6b578f", "overlay1": "#aea3c1", "overlay2": "#dad5e3",
    "text": "#ffffff", "subtext0": "#deccff", "subtext1": "#aea3c1",
    "blue": "#bb9af7", "sapphire": "#a6b8ff", "peach": "#d1bff7",
    "green": "#c2b8ff", "red": "#f07178", "mauve": "#b49ae6",
    "pink": "#c4aaf0", "yellow": "#ddccff", "maroon": "#ff8a95",
  },
  "lumon": {
    "base": "#1b2d40", "mantle": "#19293b", "crust": "#162433",
    "surface0": "#2a3b4e", "surface1": "#354658", "surface2": "#425365",
    "overlay0": "#4a6b80", "overlay1": "#89a1b2", "overlay2": "#b3c4d2",
    "text": "#d6e2ee", "subtext0": "#ffffff", "subtext1": "#89a1b2",
    "blue": "#6fb8e3", "sapphire": "#b4e4f6", "peach": "#9dcae5",
    "green": "#5e95bc", "red": "#4d86b0", "mauve": "#8bc9eb",
    "pink": "#b1d8ee", "yellow": "#6fa4c9", "maroon": "#73a6cb",
  },
  "akane": {
    "base": "#12101c", "mantle": "#110f1a", "crust": "#0e0d16",
    "surface0": "#241e27", "surface1": "#312930", "surface2": "#413639",
    "overlay0": "#6d5a68", "overlay1": "#a88a85", "overlay2": "#cfaa98",
    "text": "#f0c4a8", "subtext0": "#f7e0cc", "subtext1": "#a88a85",
    "blue": "#5b7fa8", "sapphire": "#4a9bb0", "peach": "#f6cc7a",
    "green": "#7e9a6a", "red": "#d6453d", "mauve": "#c45c78",
    "pink": "#e07a94", "yellow": "#f0b45a", "maroon": "#f06a58",
  },
  "aamis": {
    "base": "#0f0f0f", "mantle": "#0e0e0e", "crust": "#0c0c0c",
    "surface0": "#211f1e", "surface1": "#2e2c29", "surface2": "#3d3a37",
    "overlay0": "#706a6a", "overlay1": "#a79d96", "overlay2": "#ccc0b4",
    "text": "#eadccc", "subtext0": "#e6caab", "subtext1": "#a79d96",
    "blue": "#e2be8a", "sapphire": "#e8ab3b", "peach": "#edb95a",
    "green": "#cea37f", "red": "#e25d6c", "mauve": "#ede4c8",
    "pink": "#ede4c8", "yellow": "#f4bb54", "maroon": "#e9838f",
  },
  "copper_night": {
    "base": "#11111b", "mantle": "#101019", "crust": "#0e0e16",
    "surface0": "#20212c", "surface1": "#2b2d39", "surface2": "#383a49",
    "overlay0": "#585b70", "overlay1": "#8d92ab", "overlay2": "#b0b7d3",
    "text": "#cdd6f4", "subtext0": "#cdd6f4", "subtext1": "#8d92ab",
    "blue": "#89b4fa", "sapphire": "#94e2d5", "peach": "#fab387",
    "green": "#a6e3a1", "red": "#f38ba8", "mauve": "#cba6f7",
    "pink": "#cba6f7", "yellow": "#f9e2af", "maroon": "#f38ba8",
  },
  "ibm": {
    "base": "#050709", "mantle": "#050608", "crust": "#040607",
    "surface0": "#191b1d", "surface1": "#282a2b", "surface2": "#3a3b3d",
    "overlay0": "#4a4a4a", "overlay1": "#9b9b9b", "overlay2": "#d2d2d2",
    "text": "#ffffff", "subtext0": "#993426", "subtext1": "#9b9b9b",
    "blue": "#727272", "sapphire": "#a360a3", "peach": "#dadaba",
    "green": "#d24646", "red": "#66a773", "mauve": "#8686ba",
    "pink": "#afafd2", "yellow": "#b4b47b", "maroon": "#a3cfa8",
  },
  "retro_fallout": {
    "base": "#0a0f09", "mantle": "#050804", "crust": "#080c07",
    "surface0": "#152213", "surface1": "#1d311a", "surface2": "#274122",
    "overlay0": "#95ff80", "overlay1": "#95ff80", "overlay2": "#95ff80",
    "text": "#95ff80", "subtext0": "#95ff80", "subtext1": "#95ff80",
    "blue": "#6ebf5d", "sapphire": "#62a058", "peach": "#6ebf5d",
    "green": "#95ff80", "red": "#ff5555", "mauve": "#7bcf6b",
    "pink": "#62a058", "yellow": "#487041", "maroon": "#ff5555",
  },
  "solitude": {
    "base": "#101315", "mantle": "#0f1113", "crust": "#0d0f11",
    "surface0": "#1f2224", "surface1": "#2a2d2f", "surface2": "#373a3b",
    "overlay0": "#4b4e55", "overlay1": "#84878b", "overlay2": "#aaacae",
    "text": "#cacccc", "subtext0": "#cbc2be", "subtext1": "#84878b",
    "blue": "#798186", "sapphire": "#707070", "peach": "#c9c2b4",
    "green": "#9fa5a9", "red": "#565d60", "mauve": "#aeaeae",
    "pink": "#9a9a9a", "yellow": "#d9dbdc", "maroon": "#de6145",
  },
  "blackturq": {
    "base": "#0a0a0a", "mantle": "#090909", "crust": "#080808",
    "surface0": "#191b1b", "surface1": "#252727", "surface2": "#323636",
    "overlay0": "#322f3b", "overlay1": "#767d83", "overlay2": "#a2b1b4",
    "text": "#c8dcdc", "subtext0": "#c4d8e2", "subtext1": "#767d83",
    "blue": "#adf0e9", "sapphire": "#5a676b", "peach": "#a9d1d7",
    "green": "#8fecd5", "red": "#d35f5f", "mauve": "#485362",
    "pink": "#485362", "yellow": "#a9d1d7", "maroon": "#d35f5f",
  },
  # ---- Best downloads from omarchy.gallery (dark, top stars) ----
  # Upstream: OldJobobo/omarchy-miasma-theme (122 stars). Canonical Miasma
  # palette by xero, adapted to Omarchy semantic roles.
  "miasma": {
    "base": "#222222", "mantle": "#151515", "crust": "#101010",
    "surface0": "#2c2c28", "surface1": "#383838", "surface2": "#46463e",
    "overlay0": "#4a4a44", "overlay1": "#8a8a7e", "overlay2": "#a8a898",
    "text": "#c2c2b0", "subtext0": "#d7c483", "subtext1": "#8a8a7e",
    "blue": "#78824b", "sapphire": "#c9a554", "peach": "#d7c483",
    "green": "#5f875f", "red": "#b36d43", "mauve": "#bb7744",
    "pink": "#bb7744", "yellow": "#b36d43", "maroon": "#685742",
  },
  # Upstream: Justikun/omarchy-osaka-jade-theme (113 stars, alacritty-only).
  # Mapping follows the ayaka precedent (ANSI straight through).
  "osaka_jade": {
    "base": "#111c18", "mantle": "#0e1713", "crust": "#0b120e",
    "surface0": "#23372b", "surface1": "#2e4637", "surface2": "#3b5747",
    "overlay0": "#53685b", "overlay1": "#8a9a8d", "overlay2": "#b5c4b3",
    "text": "#c1c497", "subtext0": "#f6f5dd", "subtext1": "#53685b",
    "blue": "#509475", "sapphire": "#2dd5b7", "peach": "#e5c736",
    "green": "#549e6a", "red": "#ff5345", "mauve": "#d2689c",
    "pink": "#75bbb3", "yellow": "#e5c736", "maroon": "#db9f9c",
  },
  # Upstream: dhh/omarchy-giants-theme (103 stars).
  "giants": {
    "base": "#27241f", "mantle": "#1d1b17", "crust": "#141210",
    "surface0": "#3d3a35", "surface1": "#4a463e", "surface2": "#58534a",
    "overlay0": "#4f4840", "overlay1": "#8a857a", "overlay2": "#a9a092",
    "text": "#e1d5c2", "subtext0": "#e9e0d1", "subtext1": "#8a857a",
    "blue": "#97786d", "sapphire": "#d9dfb2", "peach": "#fff2c8",
    "green": "#cac4a2", "red": "#b3826a", "mauve": "#c6a48e",
    "pink": "#e3b89b", "yellow": "#fff2c8", "maroon": "#bea78c",
  },
  # Upstream: ForrestKnight/omarchy-forest-night-theme (58 stars).
  "forest_night": {
    "base": "#1a2125", "mantle": "#14191c", "crust": "#0d1113",
    "surface0": "#222a30", "surface1": "#2d3640", "surface2": "#3a4a55",
    "overlay0": "#4a5568", "overlay1": "#6b7280", "overlay2": "#a8b3bd",
    "text": "#c9d1d9", "subtext0": "#ffffff", "subtext1": "#6b7280",
    "blue": "#4ecdc4", "sapphire": "#66d9ef", "peach": "#f39c12",
    "green": "#8fbc8f", "red": "#e91e63", "mauve": "#9b59b6",
    "pink": "#9b59b6", "yellow": "#ffb74d", "maroon": "#c78a7a",
  },
  # Upstream: bjarneo/omarchy-evergreen-theme (53 stars).
  "evergreen": {
    "base": "#101913", "mantle": "#0c130e", "crust": "#080d0a",
    "surface0": "#28302b", "surface1": "#333d33", "surface2": "#3f4c3f",
    "overlay0": "#4a684a", "overlay1": "#798375", "overlay2": "#98a294",
    "text": "#a1af9c", "subtext0": "#b9c3b5", "subtext1": "#798375",
    "blue": "#4a9a68", "sapphire": "#52987a", "peach": "#d4ba60",
    "green": "#6aae52", "red": "#c87a5c", "mauve": "#8a7856",
    "pink": "#a08e66", "yellow": "#c4a64e", "maroon": "#d89268",
  },
  # Upstream: OldJobobo/omarchy-last-call-theme (53 stars).
  "last_call": {
    "base": "#0b1d20", "mantle": "#030e10", "crust": "#010506",
    "surface0": "#1e4147", "surface1": "#2a4f57", "surface2": "#42686f",
    "overlay0": "#42686f", "overlay1": "#719398", "overlay2": "#82a3a6",
    "text": "#94b3b5", "subtext0": "#e0f5f2", "subtext1": "#719398",
    "blue": "#668ca9", "sapphire": "#00c6c2", "peach": "#d07a3f",
    "green": "#58ad73", "red": "#ed634c", "mauve": "#9c8499",
    "pink": "#a4939e", "yellow": "#b79a54", "maroon": "#f47a64",
  },
  # ---- Batch 2: next 10 best downloads (dark, top stars) ----
  # Upstream: abhijeet-swami/omarchy-spectra-theme (41 stars, alacritty-only).
  # Upstream: dhh/omarchy-zonda-zoom-theme (37 stars).
  # Upstream: HANCORE-linux/omarchy-lasthorizon-theme (36 stars, ANSI-only).
  # Upstream: YutaKoyanagi10/omarchy-koyanagi-theme (34 stars, monochrome).
  # Upstream: atif-1402/omarchy-amekoji-theme (32 stars, ANSI-only).
  # Upstream: atif-1402/omarchy-aureth-theme (31 stars, ANSI-only).
  # Upstream: dhh/omarchy-diablo-dreams-theme (31 stars).
  # Upstream: OldJobobo/omarchy-retro-82-theme (30 stars).
  # Upstream: OldJobobo/omarchy-firmitas-utilitas-venustas-theme (29 stars).
  # Upstream: HANCORE-linux/omarchy-kanso-theme (28 stars, ANSI-only).
  # ---- Top-40 gallery restores (dark, by stars) ----
  # Upstream: OldJobobo/omarchy-city-783-theme (49 stars).
  "city_783": {
    "base": "#181a1f", "mantle": "#101216", "crust": "#090a0d",
    "surface0": "#20232a", "surface1": "#2b2f37", "surface2": "#3a3f48",
    "overlay0": "#4b515b", "overlay1": "#6a707a", "overlay2": "#8f949c",
    "text": "#b9bec6", "subtext0": "#eceff2", "subtext1": "#6a707a",
    "blue": "#ad2222", "sapphire": "#8f949c", "peach": "#f04a4a",
    "green": "#dce0e6", "red": "#e53939", "mauve": "#c3c8d0",
    "pink": "#c3c8d0", "yellow": "#9e1a1a", "maroon": "#ff5c5c",
  },
  # Upstream: bjarneo/omarchy-ash-theme (48 stars).
  "ash": {
    "base": "#121212", "mantle": "#0d0d0d", "crust": "#080808",
    "surface0": "#212121", "surface1": "#2e2e2e", "surface2": "#3d3d3d",
    "overlay0": "#454545", "overlay1": "#5a5a5a", "overlay2": "#8a8a8a",
    "text": "#e0e0e0", "subtext0": "#fafafa", "subtext1": "#9a9a9a",
    "blue": "#626262", "sapphire": "#767676", "peach": "#b2b2b2",
    "green": "#767676", "red": "#8a8a8a", "mauve": "#8a8a8a",
    "pink": "#8a8a8a", "yellow": "#9e9e9e", "maroon": "#9e9e9e",
  },
  # Upstream: TyRichards/omarchy-space-monkey-theme (46 stars).
  "space_monkey": {
    "base": "#1c0e00", "mantle": "#160b00", "crust": "#0f0700",
    "surface0": "#291603", "surface1": "#38200a", "surface2": "#4a2c10",
    "overlay0": "#4a3a28", "overlay1": "#948a8b", "overlay2": "#b5abae",
    "text": "#e7aa5a", "subtext0": "#f1e5e7", "subtext1": "#948a8b",
    "blue": "#66a891", "sapphire": "#bd4924", "peach": "#f9cc6c",
    "green": "#c8e292", "red": "#fd6883", "mauve": "#a8a9eb",
    "pink": "#bebffd", "yellow": "#f9cc6c", "maroon": "#ff8297",
  },
  # Upstream: JaxonWright/omarchy-midnight-theme (45 stars).
  "midnight": {
    "base": "#000000", "mantle": "#0d0d0d", "crust": "#000000",
    "surface0": "#121212", "surface1": "#1e1e1e", "surface2": "#2a2a2e",
    "overlay0": "#333333", "overlay1": "#555555", "overlay2": "#8a8a8d",
    "text": "#efefef", "subtext0": "#ffffff", "subtext1": "#8a8a8d",
    "blue": "#8a9fbe", "sapphire": "#88aabb", "peach": "#ffc107",
    "green": "#8a9a7b", "red": "#d35f5f", "mauve": "#c1a1c1",
    "pink": "#d9b9d9", "yellow": "#ffc107", "maroon": "#b91c1c",
  },
  # Upstream: euandeas/omarchy-flexoki-dark-theme (44 stars, ANSI-only).
  "flexoki_dark": {
    "base": "#100f0f", "mantle": "#0d0c0c", "crust": "#0a0909",
    "surface0": "#1e1c1a", "surface1": "#2b2825", "surface2": "#403e3c",
    "overlay0": "#4a4741", "overlay1": "#6f6e69", "overlay2": "#878580",
    "text": "#cecdc3", "subtext0": "#e0ded4", "subtext1": "#6f6e69",
    "blue": "#4385be", "sapphire": "#24837b", "peach": "#d0a215",
    "green": "#66800b", "red": "#d14d41", "mauve": "#a02f6f",
    "pink": "#ce5d97", "yellow": "#ad8301", "maroon": "#af3029",
  },
  # Upstream: abhijeet-swami/omarchy-spectra-theme (41 stars, alacritty-only).
  "spectra": {
    "base": "#1a1b1e", "mantle": "#16171a", "crust": "#121316",
    "surface0": "#2b2d31", "surface1": "#36383e", "surface2": "#46484f",
    "overlay0": "#505258", "overlay1": "#8a8d94", "overlay2": "#b5b8bf",
    "text": "#eaeaef", "subtext0": "#ffffff", "subtext1": "#8a8d94",
    "blue": "#7ca5ff", "sapphire": "#7dd8d3", "peach": "#f7c553",
    "green": "#8edb73", "red": "#ef5d67", "mauve": "#e29ef3",
    "pink": "#efb5f9", "yellow": "#ffd86f", "maroon": "#ff7680",
  },
  # Upstream: bjarneo/omarchy-futurism-theme (40 stars).
  "futurism": {
    "base": "#0a1428", "mantle": "#080f1e", "crust": "#050a14",
    "surface0": "#17294a", "surface1": "#1f355e", "surface2": "#2a4372",
    "overlay0": "#33445c", "overlay1": "#53627a", "overlay2": "#9dacbe",
    "text": "#f0f8ff", "subtext0": "#ffffff", "subtext1": "#9dacbe",
    "blue": "#5076b2", "sapphire": "#00bfff", "peach": "#ff7ab8",
    "green": "#00bfff", "red": "#ff40a3", "mauve": "#ff40a3",
    "pink": "#ff7ab8", "yellow": "#6a90d2", "maroon": "#80305d",
  },
  # Upstream: HANCORE-linux/omarchy-batou-theme (38 stars, ANSI-only).
  "batou": {
    "base": "#121212", "mantle": "#0f0f0f", "crust": "#0c0c0c",
    "surface0": "#242220", "surface1": "#383735", "surface2": "#464442",
    "overlay0": "#4a4642", "overlay1": "#6e6a66", "overlay2": "#8a8575",
    "text": "#a4a4a4", "subtext0": "#dbd9d3", "subtext1": "#6e6a66",
    "blue": "#605d5b", "sapphire": "#c2bbb0", "peach": "#e19e74",
    "green": "#a5a297", "red": "#e19e74", "mauve": "#8a8575",
    "pink": "#b3adad", "yellow": "#c6c4b0", "maroon": "#984b1e",
  },
  # Upstream: dhh/omarchy-zonda-zoom-theme (37 stars).
  "zonda_zoom": {
    "base": "#141313", "mantle": "#0f0e0e", "crust": "#0a0a0a",
    "surface0": "#2c2b2b", "surface1": "#383738", "surface2": "#464545",
    "overlay0": "#4a4848", "overlay1": "#a39c9c", "overlay2": "#b9b7b1",
    "text": "#f6f4ec", "subtext0": "#f8f7f1", "subtext1": "#a39c9c",
    "blue": "#6b7fbe", "sapphire": "#637eb5", "peach": "#cde3ff",
    "green": "#bcd2ff", "red": "#a0afe3", "mauve": "#757fbb",
    "pink": "#99a1ee", "yellow": "#cde3ff", "maroon": "#bdccff",
  },
  # Upstream: OldJobobo/omarchy-sakura-mochi-theme (37 stars).
  "sakura_mochi": {
    "base": "#0b0d11", "mantle": "#080a0d", "crust": "#060709",
    "surface0": "#19171c", "surface1": "#242229", "surface2": "#322e36",
    "overlay0": "#3f3b44", "overlay1": "#678270", "overlay2": "#8a9a90",
    "text": "#f0b7ca", "subtext0": "#fff1f6", "subtext1": "#678270",
    "blue": "#67dd82", "sapphire": "#6f9485", "peach": "#d7be96",
    "green": "#5aa15d", "red": "#f23888", "mauve": "#f0b7ca",
    "pink": "#ffd0dc", "yellow": "#d7be96", "maroon": "#ff6aa7",
  },
  # Upstream: mwaltzer/omarchy-bauhaus-theme (37 stars, alacritty-authoritative).
  "bauhaus": {
    "base": "#101318", "mantle": "#0e1115", "crust": "#0b0e11",
    "surface0": "#161b22", "surface1": "#222733", "surface2": "#2b3040",
    "overlay0": "#3a3f4c", "overlay1": "#5c626c", "overlay2": "#98a0ae",
    "text": "#eaeff5", "subtext0": "#ffffff", "subtext1": "#98a0ae",
    "blue": "#8999aa", "sapphire": "#809d9e", "peach": "#e7a46f",
    "green": "#789fa2", "red": "#cb886d", "mauve": "#8d758f",
    "pink": "#a3ada7", "yellow": "#e0a568", "maroon": "#e06c55",
  },
  # Upstream: tahayvr/omarchy-gold-rush-theme (36 stars, ANSI-only).
  "gold_rush": {
    "base": "#121212", "mantle": "#0e0e0e", "crust": "#0b0b0b",
    "surface0": "#1f1c14", "surface1": "#2c281b", "surface2": "#3a3424",
    "overlay0": "#524a2e", "overlay1": "#6e6238", "overlay2": "#8f8148",
    "text": "#d9d9d9", "subtext0": "#ece5cc", "subtext1": "#8a7a44",
    "blue": "#926c15", "sapphire": "#b69121", "peach": "#ffee69",
    "green": "#a47e1b", "red": "#dbb42c", "mauve": "#c9a227",
    "pink": "#edc531", "yellow": "#fad643", "maroon": "#dbb42c",
  },
  # Upstream: OldJobobo/omarchy-event-horizon-theme (36 stars).
  "event_horizon": {
    "base": "#1c1e26", "mantle": "#15171d", "crust": "#0e0f13",
    "surface0": "#232530", "surface1": "#2e303e", "surface2": "#3b3d4d",
    "overlay0": "#43454e", "overlay1": "#6f6f70", "overlay2": "#9da0a2",
    "text": "#cbced0", "subtext0": "#e3e6ee", "subtext1": "#9da0a2",
    "blue": "#26bbd9", "sapphire": "#59e1e3", "peach": "#fac29a",
    "green": "#29d398", "red": "#e95678", "mauve": "#ee64ac",
    "pink": "#f075b5", "yellow": "#fbc3a7", "maroon": "#ec6a88",
  },
  # Upstream: HANCORE-linux/omarchy-lasthorizon-theme (36 stars, ANSI-only).
  "lasthorizon": {
    "base": "#1f211b", "mantle": "#1a1d16", "crust": "#151712",
    "surface0": "#2c2f26", "surface1": "#3a3e32", "surface2": "#52554d",
    "overlay0": "#52554d", "overlay1": "#8a8d84", "overlay2": "#b5b8ae",
    "text": "#ffffff", "subtext0": "#fef4eb", "subtext1": "#8a8d84",
    "blue": "#d7857f", "sapphire": "#f3b788", "peach": "#f5c498",
    "green": "#f7d1ab", "red": "#d75450", "mauve": "#c6a49f",
    "pink": "#e9dad8", "yellow": "#f5c498", "maroon": "#ec9997",
  },
}

try:
    with open(extra) as f:
        p.update(json.load(f))
except OSError:
    pass

c = p[flavor]
def lum(h):
    h = h.lstrip("#")
    r = int(h[0:2], 16) / 255.0
    g = int(h[2:4], 16) / 255.0
    b = int(h[4:6], 16) / 255.0
    return 0.2126 * r + 0.7152 * g + 0.0722 * b
def on(h):
    return c["crust"] if lum(h) > 0.5 else c["text"]

md = {
    "surface_container_lowest": c["base"],
    "surface_container_low":    c["mantle"],
    "surface":                  c["crust"],
    "surface_container":        c["surface0"],
    "surface_container_high":   c["surface1"],
    "surface_container_highest":c["surface2"],
    "surface_variant":          c["surface1"],
    "surface_dim":              c["base"],
    "surface_bright":           c["surface1"],
    "background":               c["crust"],
    "on_background":            c["text"],
    "on_surface":               c["text"],
    "on_surface_variant":       c["subtext0"],
    "outline":                  c["subtext1"],
    "outline_variant":          c["overlay1"],
    "shadow":                   "#000000",
    "scrim":                    "#000000",
    "surface_tint":             c["blue"],
    "inverse_surface":          c["overlay0"],
    "inverse_on_surface":       c["base"],
    "source_color":             c["blue"],
    "inverse_primary":          c["mauve"],
}

# Expose the theme's accent green/mauve as first-class MD3 roles so any
# matugen template can use {{colors.green.*.hex}} / {{colors.mauve.*.hex}}.
md["green"] = c["green"]
md["mauve"] = c["mauve"]

# Additional raw accent hues as first-class roles. Not every palette defines
# each hue, so fall back to a visually-related color it does define.
extra_hues = [
    ("teal", "green"),
    ("sky", "sapphire"),
    ("lavender", "mauve"),
    ("flamingo", "peach"),
    ("rosewater", "pink"),
    ("maroon", "maroon"),
]
for role, fallback in extra_hues:
    md[role] = c.get(role, c[fallback])
    md["on_" + role] = on(md[role])

accents = [("primary", c["blue"]), ("secondary", c["green"]),
           ("tertiary", c["peach"]), ("error", c["red"])]
containers = [("primary", c["sapphire"]), ("secondary", c["yellow"]),
              ("tertiary", c["pink"]), ("error", c["maroon"])]
fixed = [("primary", c["sapphire"]), ("secondary", c["yellow"]),
         ("tertiary", c["pink"])]
dims = {"primary": "blue", "secondary": "green", "tertiary": "peach"}

for role, col in accents:
    md[role] = col
    md["on_" + role] = on(col)
for role, col in containers:
    md[role + "_container"] = col
    md["on_" + role + "_container"] = on(col)
for role, col in fixed:
    md[role + "_fixed"] = col
    md["on_" + role + "_fixed"] = on(col)
    md[role + "_fixed_dim"] = c[dims[role]]
    md["on_" + role + "_fixed_variant"] = c["overlay1"]

def wrap(h):
    return {"default": {"hex": h, "color": h}, "dark": {"hex": h, "color": h},
            "light": {"hex": h, "color": h}}

with open(out, "w") as f:
    json.dump({"colors": {k: wrap(v) for k, v in md.items()}}, f)
PY
  echo "$out"
}

# Fixed serpantinum palettes are generated from the palette json, everything
# else comes from the wallpaper image (or a chosen color).
PRESET=""
case "$SCHEME" in
  serpantinum|catppuccin|mocha)      PRESET="mocha"  ;;
  catppuccin_frappe|frappe)          PRESET="frappe" ;;
  catppuccin_latte|latte)            PRESET="latte"  ;;
  catppuccin_macchiato|macchiato)    PRESET="macchiato" ;;
  nord)                              PRESET="nord" ;;
  tokyo|tokyonight|tokyo_night)      PRESET="tokyo" ;;
  dracula)                           PRESET="dracula" ;;
  gruvbox)                           PRESET="gruvbox" ;;
  rosepine|rose_pine)                PRESET="rosepine" ;;
  kanagawa)                          PRESET="kanagawa" ;;
  everforest)                        PRESET="everforest" ;;
  solarized)                         PRESET="solarized" ;;
  onedark)                  PRESET="onedark" ;;
  ayu)                               PRESET="ayu" ;;
  horizon)                           PRESET="horizon" ;;
  nightowl|night_owl)                PRESET="nightowl" ;;
  nothing)                           PRESET="nothing" ;;
  material)                          PRESET="material" ;;
  monokai)                           PRESET="monokai" ;;
  palenight)                         PRESET="palenight" ;;
  oceanic)                           PRESET="oceanic" ;;
  snazzy)                            PRESET="snazzy" ;;
  github_dark|github-dark)           PRESET="github_dark" ;;
  nightfox)                          PRESET="nightfox" ;;
  rosepine_moon)      PRESET="rosepine_moon" ;;
  rosepine_dawn|rose_pine_dawn)      PRESET="rosepine_dawn" ;;
  zenburn)                           PRESET="zenburn" ;;
  synthwave)                         PRESET="synthwave" ;;
  doom)                              PRESET="doom" ;;
  vscode_dark|vscode-dark)           PRESET="vscode_dark" ;;
  moonfly)                           PRESET="moonfly" ;;
  cobalt)                    PRESET="cobalt" ;;
  wombat)                            PRESET="wombat" ;;
  shades_of_purple|shades-of-purple) PRESET="shades_of_purple" ;;
  solarized_light)                   PRESET="solarized_light" ;;
  gruvbox_light)                     PRESET="gruvbox_light" ;;
  tokyoday)                          PRESET="tokyoday" ;;
  everforest_light)                  PRESET="everforest_light" ;;
  # Omarchy community themes (https://omarchy.org/themes)
  aetheria)                       PRESET="aetheria" ;;
  ayaka)                          PRESET="ayaka" ;;
  black_gold)                     PRESET="black_gold" ;;
  felix)                          PRESET="felix" ;;
  harbor_dark)                    PRESET="harbor_dark" ;;
  hermarchy)                      PRESET="hermarchy" ;;
  mars)                           PRESET="mars" ;;
  mechanoonna)                    PRESET="mechanoonna" ;;
  one_dark_pro)                   PRESET="one_dark_pro" ;;
  rainy_night)                    PRESET="rainy_night" ;;
  retropc)                        PRESET="retropc" ;;
  void)                           PRESET="void" ;;
  lumon)                          PRESET="lumon" ;;
  akane)                          PRESET="akane" ;;
  aamis)                          PRESET="aamis" ;;
  copper_night)                   PRESET="copper_night" ;;
  ibm)                            PRESET="ibm" ;;
  retro_fallout)                  PRESET="retro_fallout" ;;
  solitude)                       PRESET="solitude" ;;
  blackturq)                      PRESET="blackturq" ;;
  # Best downloads from omarchy.gallery (dark, top stars)
  miasma)                         PRESET="miasma" ;;
  osaka_jade|osaka-jade)          PRESET="osaka_jade" ;;
  giants)                         PRESET="giants" ;;
  forest_night|forest-night)      PRESET="forest_night" ;;
  evergreen)                      PRESET="evergreen" ;;
  last_call|last-call)            PRESET="last_call" ;;
  city_783|city-783)                PRESET="city_783" ;;
  ash)                              PRESET="ash" ;;
  space_monkey|space-monkey)        PRESET="space_monkey" ;;
  midnight)                         PRESET="midnight" ;;
  flexoki_dark|flexoki-dark)        PRESET="flexoki_dark" ;;
  spectra)                          PRESET="spectra" ;;
  futurism)                         PRESET="futurism" ;;
  batou)                            PRESET="batou" ;;
  zonda_zoom|zonda-zoom)            PRESET="zonda_zoom" ;;
  sakura_mochi|sakura-mochi)        PRESET="sakura_mochi" ;;
  bauhaus)                          PRESET="bauhaus" ;;
  gold_rush|gold-rush)              PRESET="gold_rush" ;;
  event_horizon|event-horizon)      PRESET="event_horizon" ;;
  lasthorizon)                      PRESET="lasthorizon" ;;
  bw|blackwhite|black_white)         PRESET="bw" ;;
  # NvChad base46 themes (nvim), stored in nvim_themes.json
  nv_*)                              PRESET="${SCHEME#nv_}"
        if ! python3 - "$PRESET" "$EXTRA_PALETTES" <<'PY'
import json, sys
sys.exit(0 if sys.argv[1] in json.load(open(sys.argv[2])) else 1)
PY
        then PRESET=""; TYPE="scheme-tonal-spot"; fi ;;
  *) if [ -f "$EXTRA_PALETTES" ] && python3 - "$SCHEME" "$EXTRA_PALETTES" <<'PY'
import json, sys
sys.exit(0 if sys.argv[1] in json.load(open(sys.argv[2])) else 1)
PY
     then PRESET="$SCHEME"
      else TYPE="scheme-tonal-spot"
      fi ;;
esac

# One mode: derive light/dark from the scheme itself.
# - fixed/nvim presets: relative luminance of the palette's base color
# - wallpaper_color: luminance of the chosen hex
# - auto (wallpaper-derived): mean luminance of the wallpaper image
# Light schemes -> light system, dark schemes -> dark system.
derive_mode_from_scheme() {
  local base=""
  if [ -n "${PRESET:-}" ]; then
    base="$(python3 - "$PRESET" "$EXTRA_PALETTES" "$0" <<'PY'
import json, sys
flavor, extra, script = sys.argv[1:4]
base = ""
try:
    body = open(script).read().split("<<'PY'", 1)[1].split("\nPY", 1)[0]
    ns, argv = {}, sys.argv
    sys.argv = ["_", "mocha", "/tmp/derive_mode_dummy.json", extra]
    try:
        exec(body, ns)
    finally:
        sys.argv = argv
    base = (ns.get("p", {}).get(flavor) or {}).get("base", "")
except Exception:
    pass
if not base:
    try:
        base = (json.load(open(extra)).get(flavor) or {}).get("base", "")
    except Exception:
        pass
print(base)
PY
)"
  else
    case "${SCHEME:-}" in
      wallpaper_color|wallpaper-color|color) base="#${HEX//#/}" ;;
    esac
  fi
  local lum=""
  if [ -n "$base" ]; then
    lum="$(python3 - "$base" <<'PY'
import sys
hx = sys.argv[1].lstrip("#")
try:
    r, g, b = [int(hx[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    f = lambda c: c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4
    print(f(r) * 0.2126 + f(g) * 0.7152 + f(b) * 0.0722)
except Exception:
    pass
PY
)"
  elif [ -f "${IMG:-}" ]; then
    lum="$(magick "$IMG" -auto-orient -thumbnail '64x64>' -format '%[fx:mean]' info: 2>/dev/null)" || lum=""
  fi
  if [ -n "$lum" ] && python3 -c "import sys; sys.exit(0 if float(sys.argv[1]) >= 0.40 else 1)" "$lum" 2>/dev/null; then
    MODE="light"; PREFER="lightness"; QUICK='{"mode": "light"}'
  else
    MODE="dark"; PREFER="darkness"; QUICK='{"mode": "dark"}'
  fi
  echo "@@stage mode-$MODE"
}

derive_mode_from_scheme

if [ -n "$PRESET" ]; then
  MATUGEN=(json "$(apply_preset "$PRESET")")
else
  MATUGEN=(image "$IMG")
  TYPE=""
  case "$SCHEME" in
    wallpaper_color|wallpaper-color|color)
        HEX="${HEX//#/}"
        [ ${#HEX} -eq 6 ] || { echo "wallpaper_apply: color scheme needs hex" >&2; exit 1; }
        MATUGEN=(color hex "$HEX")
        ;;
    tonal_spot|default)  TYPE="scheme-tonal-spot" ;;
    content)             TYPE="scheme-content" ;;
    expressive)          TYPE="scheme-expressive" ;;
    fidelity)            TYPE="scheme-fidelity" ;;
    fruit_salad)         TYPE="scheme-fruit-salad" ;;
    monochrome)          TYPE="scheme-monochrome" ;;
    neutral)             TYPE="scheme-neutral" ;;
    rainbow)             TYPE="scheme-rainbow" ;;
    smart)               TYPE="scheme-smart" ;;
    vibrant)             TYPE="scheme-vibrant" ;;
    *)                   TYPE="scheme-tonal-spot" ;;
  esac
  [ -n "$TYPE" ] && MATUGEN+=(--type "$TYPE")
  MATUGEN+=(--prefer "$PREFER")
fi

# Widget colors (yt-x, clipboard, notification, launcher) follow matugen
# normally. When widget colors should stay put (PIN_WIDGETS=1, used by the
# color-scheme picker) we snapshot the current widget colors before matugen
# rewrites colors.js and re-apply them after, so those widgets stay put
# (shell parses colors.js last-wins).
COLOR_JS="$HOME/.config/quickshell/colors.js"
widget_snapshot=""
if [ "$PIN_WIDGETS" = "1" ] && [ -f "$COLOR_JS" ]; then
  widget_snapshot="$(python3 - "$COLOR_JS" <<'PY'
import re, sys
content = open(sys.argv[1]).read()
keys = ["ytx_card","ytx_card_light","widget_card","widget_card_light","launcher_card","launcher_card_light","notes_card","notes_card_light","whatsapp_card","whatsapp_card_light","notif_card","notif_card_light","widget_accent","widget_accent_light","widget_border","widget_border_light","widget_error","widget_error_light"]
lines = []
for k in keys:
    m = re.findall(r'var\s+%s\s*=\s*"([^"]*)"' % k, content)
    if m:
        lines.append(f'var {k} = "{m[-1]}"')
print("\n".join(lines))
PY
)"
fi

# Mango has no native wallpaper setter; the image goes through awww's
# layer-shell surface. exec-once autostart only covers session start, and a
# stale/dead daemon (leftover socket, connection refused) makes every apply
# fail, so make sure the daemon is actually answering before we set anything.
if ! awww query >/dev/null 2>&1; then
  pkill -x awww-daemon 2>/dev/null || true
  (setsid -f awww-daemon </dev/null >/dev/null 2>&1 &)
  for i in $(seq 1 40); do
    awww query >/dev/null 2>&1 && break
    sleep 0.25
  done
fi

echo "@@stage wallpaper"
# awww re-reads every cached sprite-sheet on each `img` call; clear the cache
# so the new image decodes fresh instead of animating from stale frames.
awww clear-cache 2>/dev/null || true
# Single wallpaper set, FIRST: a short fade so the new photo is visible
# immediately; the ~1s theme generation below then settles the colors.
# (matugen's own wallpaper hook stays off to avoid setting it twice.)
awww img "$IMG" --transition-type fade --transition-duration 0.6 --transition-fps 60

echo "@@stage theme"
matugen "${MATUGEN[@]}" --mode "$MODE"

# Accent green/mauve into colors.js: preset runs already carry native theme
# green/mauve roles; image runs get them by hue-rotating the source color so
# the accents always exist and follow the active wallpaper.
PALETTE_JSON=""
if [ -n "$PRESET" ]; then PALETTE_JSON="$CACHE/palette_${PRESET}.json"; fi
python3 - "$COLOR_JS" "$PALETTE_JSON" <<'PY'
import colorsys, json, os, re, sys
COLOR_JS, PALETTE_JSON = sys.argv[1], sys.argv[2] or ""
content = open(COLOR_JS).read()


def grab(k):
    m = re.findall(r'var\s+%s\s*=\s*"([^"]*)"' % k, content)
    return m[-1] if m else None


def rot(hx, target, lo=0.62, hi=0.78):
    hx = hx.lstrip("#")
    r, g, b = [int(hx[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    h, l, s = colorsys.rgb_to_hls(r, g, b)
    # Clamp lightness into a readable pill band so a too-dark source can't
    # produce near-black accents.
    l = max(lo, min(hi, l))
    return "#%02x%02x%02x" % tuple(
        round(c * 255) for c in colorsys.hls_to_rgb(target, l, s))


def norm(hx, lo=0.62, hi=0.78):
    """Keep hue/saturation, remap lightness into the pill band."""
    hx = hx.lstrip("#")
    r, g, b = [int(hx[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    h, l, s = colorsys.rgb_to_hls(r, g, b)
    l = max(lo, min(hi, l))
    return "#%02x%02x%02x" % tuple(
        round(c * 255) for c in colorsys.hls_to_rgb(h, l, s))


src = grab("source") or grab("primary") or "#808080"
src_l = grab("source_light") or src

green = mauve = ""
pctx = None
if PALETTE_JSON and os.path.isfile(PALETTE_JSON):
    try:
        pctx = json.load(open(PALETTE_JSON)).get("colors", {})
    except Exception:
        pctx = None
if pctx and "green" in pctx:
    green = norm(pctx["green"]["default"]["hex"])
    mauve = norm(pctx["mauve"]["default"]["hex"])
else:
    green = rot(src, 1.0 / 3.0)
    mauve = rot(src, 0.75)

marker = "/* Matugen accent green/mauve */"
idx = content.find(marker)
if idx != -1:
    content = content[:idx]
block = (marker + "\n"
         + 'var green = "%s"\n' % green
         + 'var green_light = "%s"\n' % norm(rot(src_l, 1.0 / 3.0, 0.7, 0.82), 0.7, 0.82)
         + 'var mauve = "%s"\n' % mauve
         + 'var mauve_light = "%s"\n' % norm(rot(src_l, 0.75, 0.7, 0.82), 0.7, 0.82) + "\n")
with open(COLOR_JS, "w") as f:
    f.write(content.rstrip("\n") + "\n\n" + block)
PY

if [ "$PIN_WIDGETS" = "1" ] && [ -n "$widget_snapshot" ]; then
  printf '\n/* Widget colors pinned by color-scheme picker */\n%s\n' "$widget_snapshot" >> "$COLOR_JS"
fi

# Wallpaper was already set (fast fade) before theming — nothing left to do
# here except remember the selection.

# System light/dark: GTK + icons + portal color-scheme + terminal + Qt.
# matugen only recolors its own templates; the desktop itself follows these
# settings, so the picker mode drives the whole system, not just wallpaper
# apps. LibreWolf/Electron follow the portal automatically (no hardcoded
# prefs); Qt/GTK2/Xwayland read the config files below.
apply_system_theme() {
  local mode="$1" # light | dark
  local gtk_theme icon_theme color_scheme prefer_dark wm_theme qt_scheme foot_sig foot_init
  if [ "$mode" = "light" ]; then
    gtk_theme="adw-gtk3"; icon_theme="MacTahoe-light"; color_scheme="prefer-light"
    prefer_dark=0; wm_theme="Adwaita"; qt_scheme="airy.conf"
    foot_sig="-USR2"; foot_init="light"
  else
    gtk_theme="adw-gtk3-dark"; icon_theme="MacTahoe-dark"; color_scheme="prefer-dark"
    prefer_dark=1; wm_theme="Adwaita-dark"; qt_scheme="darker.conf"
    foot_sig="-USR1"; foot_init="dark"
  fi
  # Live settings: running GTK apps + xdg-desktop-portal read these.
  gsettings set org.gnome.desktop.interface gtk-theme "$gtk_theme" 2>/dev/null || true
  gsettings set org.gnome.desktop.interface icon-theme "$icon_theme" 2>/dev/null || true
  gsettings set org.gnome.desktop.interface color-scheme "$color_scheme" 2>/dev/null || true
  gsettings set org.gnome.desktop.wm.preferences theme "$wm_theme" 2>/dev/null || true
  # On-disk settings for new launches.
  for f in "$HOME/.config/gtk-3.0/settings.ini" "$HOME/.config/gtk-4.0/settings.ini"; do
    [ -f "$f" ] || continue
    sed -i "s/^gtk-theme-name=.*/gtk-theme-name=$gtk_theme/" "$f" || true
    sed -i "s/^gtk-icon-theme-name=.*/gtk-icon-theme-name=$icon_theme/" "$f" || true
    sed -i "s/^gtk-application-prefer-dark-theme=.*/gtk-application-prefer-dark-theme=$prefer_dark/" "$f" || true
  done
  # XSETTINGS (Xwayland) + GTK2 (pcmanfm).
  [ -f "$HOME/.config/xsettingsd/xsettingsd.conf" ] && sed -i "s/^Net\/ThemeName .*/Net\/ThemeName \"$gtk_theme\"/" "$HOME/.config/xsettingsd/xsettingsd.conf" || true
  [ -f "$HOME/.config/xsettingsd/xsettingsd.conf" ] && sed -i "s/^Net\/IconThemeName .*/Net\/IconThemeName \"$icon_theme\"/" "$HOME/.config/xsettingsd/xsettingsd.conf" || true
  [ -f "$HOME/.gtkrc-2.0" ] && sed -i "s/^gtk-theme-name=.*/gtk-theme-name=\"$gtk_theme\"/" "$HOME/.gtkrc-2.0" || true
  [ -f "$HOME/.gtkrc-2.0" ] && sed -i "s/^gtk-icon-theme-name=.*/gtk-icon-theme-name=\"$icon_theme\"/" "$HOME/.gtkrc-2.0" || true
  # Qt5ct palette.
  [ -f "$HOME/.config/qt5ct/qt5ct.conf" ] && sed -i "s|^color_scheme_path=.*|color_scheme_path=/usr/share/qt5ct/colors/$qt_scheme|" "$HOME/.config/qt5ct/qt5ct.conf" || true
  # Foot: default for new windows + live-switch running ones.
  [ -f "$HOME/.config/foot/foot.ini" ] && sed -i "s/^initial-color-theme=.*/initial-color-theme=$foot_init/" "$HOME/.config/foot/foot.ini" || true
  pkill "$foot_sig" foot 2>/dev/null || true
}

# QuickShell only: write the chosen light/dark mode for the bar to read.
# Matugen stays dark/light per PREFER but qs-theme only affects QuickShell's
# pill coloring (the rest of the system follows the matugen run above).
printf '%s\n' "$QUICK" > "$QUICK_THEME_FILE"

echo "@@stage system"
apply_system_theme "$MODE"

# Remember the last applied wallpaper so the picker can preselect it.
printf '%s\n' "$IMG" > "$CACHE/current.txt"
printf '%s\n%s\n' "$SCHEME" "$HEX" > "$CACHE/scheme.txt.tmp"
mv -f "$CACHE/scheme.txt.tmp" "$CACHE/scheme.txt"

exit 0