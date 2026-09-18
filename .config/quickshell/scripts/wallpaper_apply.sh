#!/usr/bin/env bash
# Apply a wallpaper with full matugen customization — Drop-in replacement
# for ~/.config/rofi/wallpaper-changer/launcher.sh.
#
# usage:
#   wallpaper_apply.sh <image_path> <mode:dark|light> <scheme> [hex]=RRGGBB [pin_widgets=0|1]
#
# mode:   dark | light         (matugen --prefer + QuickShell qs-theme.json)
# scheme: tonal_spot|content|fidelity|vibrant|neutral|monochrome|rainbow
#         (fixed presets) serpantinum|catppuccin_frappe|catppuccin_macchiato|catppuccin_latte|
#         nord|tokyo|dracula|gruvbox|rosepine|kanagawa
#         bw|blackwhite|black_white        (pure black & white monochrome)
#         wallpaper_color                            (from a chosen hex)
#   wallpaper_color requires a 4th arg: the RGB hex to generate from.

set -e

IMG="$1"
MODE="${2:-dark}"
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

# matugen prefer
case "$MODE" in
  light|Light) MODE="light"; PREFER="lightness"; QUICK='{"mode": "light"}'; ;;
  *)           MODE="dark"; PREFER="darkness"; QUICK='{"mode": "dark"}'; ;;
esac

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
  onedark|one_dark)                  PRESET="onedark" ;;
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
  rosepine_moon|rose_pine_moon)      PRESET="rosepine_moon" ;;
  rosepine_dawn|rose_pine_dawn)      PRESET="rosepine_dawn" ;;
  zenburn)                           PRESET="zenburn" ;;
  synthwave)                         PRESET="synthwave" ;;
  doom)                              PRESET="doom" ;;
  vscode_dark|vscode-dark)           PRESET="vscode_dark" ;;
  moonfly)                           PRESET="moonfly" ;;
  cobalt|cobalt2)                    PRESET="cobalt" ;;
  wombat)                            PRESET="wombat" ;;
  shades_of_purple|shades-of-purple) PRESET="shades_of_purple" ;;
  solarized_light)                   PRESET="solarized_light" ;;
  gruvbox_light)                     PRESET="gruvbox_light" ;;
  tokyoday)                          PRESET="tokyoday" ;;
  everforest_light)                  PRESET="everforest_light" ;;
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
keys = ["ytx_card","ytx_card_light","widget_card","widget_card_light","launcher_card","launcher_card_light","notes_card","notes_card_light","whatsapp_card","whatsapp_card_light","notif_card","notif_card_light","widget_accent","widget_border","widget_error"]
lines = []
for k in keys:
    m = re.findall(r'var\s+%s\s*=\s*"([^"]*)"' % k, content)
    if m:
        lines.append(f'var {k} = "{m[-1]}"')
print("\n".join(lines))
PY
)"
fi

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

# awww re-reads every cached sprite-sheet on each `img` call; clear the cache
# so applying stays instant.
awww clear-cache 2>/dev/null || true
awww img "$IMG" --transition-type random --transition-duration 2.0

# Niri overview backdrop: pre-blurred copy for swaybg (place-within-backdrop).
BLUR_BG="$HOME/.cache/niri-backdrop-blur.jpg"
(magick "$IMG"[0] -resize 1920x -blur 0x30 -fill "#11111b" -colorize 30% "$BLUR_BG" 2>/dev/null && pkill -x swaybg 2>/dev/null; setsid -f swaybg -i "$BLUR_BG" -m fill </dev/null >/dev/null 2>&1 &) 2>/dev/null || true

# QuickShell only: write the chosen light/dark mode for the bar to read.
# Matugen stays dark/light per PREFER but qs-theme only affects QuickShell's
# pill coloring (the rest of the system follows the matugen run above).
printf '%s\n' "$QUICK" > "$QUICK_THEME_FILE"

# Remember the last applied wallpaper so the picker can preselect it.
printf '%s\n' "$IMG" > "$CACHE/current.txt"
printf '%s\n%s\n' "$SCHEME" "$HEX" > "$CACHE/scheme.txt.tmp"
mv -f "$CACHE/scheme.txt.tmp" "$CACHE/scheme.txt"

exit 0