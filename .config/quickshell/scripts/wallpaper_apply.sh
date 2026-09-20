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
  "amberbyte": {
    "base": "#1b1112", "mantle": "#1a0e0e", "crust": "#160e0e",
    "surface0": "#2c2223", "surface1": "#392f30", "surface2": "#483e3f",
    "overlay0": "#2b1818", "overlay1": "#857676", "overlay2": "#c0b4b4",
    "text": "#f2e8e8", "subtext0": "#fff1f1", "subtext1": "#857676",
    "blue": "#d66b6b", "sapphire": "#f48a8a", "peach": "#e87f7f",
    "green": "#c05a5a", "red": "#b44a4a", "mauve": "#d66b6b",
    "pink": "#f2a3a3", "yellow": "#d66b6b", "maroon": "#c85c5c",
  },
  "arc_blueberry": {
    "base": "#111422", "mantle": "#10121f", "crust": "#0e101b",
    "surface0": "#1f2231", "surface1": "#292c3c", "surface2": "#353849",
    "overlay0": "#424761", "overlay1": "#797e98", "overlay2": "#9ea2bd",
    "text": "#bcc1dc", "subtext0": "#ffffff", "subtext1": "#797e98",
    "blue": "#69c3ff", "sapphire": "#22ecdb", "peach": "#ffe17a",
    "green": "#3cec85", "red": "#e35535", "mauve": "#f38cec",
    "pink": "#ffaff9", "yellow": "#eacd61", "maroon": "#ff6947",
  },
  "archwave": {
    "base": "#1a0d2e", "mantle": "#2d1b4e", "crust": "#150a25",
    "surface0": "#29193f", "surface1": "#34224b", "surface2": "#412d5a",
    "overlay0": "#543a6e", "overlay1": "#8e6aaf", "overlay2": "#b48adb",
    "text": "#d4a5ff", "subtext0": "#ffffff", "subtext1": "#8e6aaf",
    "blue": "#8b9aff", "sapphire": "#5ffbf1", "peach": "#fbf9a5",
    "green": "#5ffbf1", "red": "#ff6ec7", "mauve": "#f4a5ff",
    "pink": "#ffc8ff", "yellow": "#f9f871", "maroon": "#ff9adc",
  },
  "ash": {
    "base": "#121212", "mantle": "#111111", "crust": "#0e0e0e",
    "surface0": "#222222", "surface1": "#2f2f2f", "surface2": "#3d3d3d",
    "overlay0": "#5a5a5a", "overlay1": "#969696", "overlay2": "#bebebe",
    "text": "#e0e0e0", "subtext0": "#fafafa", "subtext1": "#969696",
    "blue": "#626262", "sapphire": "#767676", "peach": "#b2b2b2",
    "green": "#767676", "red": "#8a8a8a", "mauve": "#8a8a8a",
    "pink": "#8a8a8a", "yellow": "#9e9e9e", "maroon": "#9e9e9e",
  },
  "artzen": {
    "base": "#181c1f", "mantle": "#161a1d", "crust": "#131619",
    "surface0": "#2a2e30", "surface1": "#383b3d", "surface2": "#484a4d",
    "overlay0": "#b18d85", "overlay1": "#d3beb9", "overlay2": "#eadedb",
    "text": "#fdf9f8", "subtext0": "#edbcb3", "subtext1": "#d3beb9",
    "blue": "#b97670", "sapphire": "#da7a6f", "peach": "#d7adad",
    "green": "#9f6769", "red": "#9b584d", "mauve": "#9a8c8a",
    "pink": "#c4bcbb", "yellow": "#bb6d6c", "maroon": "#ca887f",
  },
  "aura": {
    "base": "#282a36", "mantle": "#252732", "crust": "#20222b",
    "surface0": "#393a45", "surface1": "#454750", "surface2": "#54555d",
    "overlay0": "#44475a", "overlay1": "#95979e", "overlay2": "#cbcccc",
    "text": "#f8f8f2", "subtext0": "#ffffff", "subtext1": "#95979e",
    "blue": "#8be9fd", "sapphire": "#8be9fd", "peach": "#cbc3e3",
    "green": "#8be9fd", "red": "#ffafcc", "mauve": "#ffc8dd",
    "pink": "#ffc8dd", "yellow": "#cbc3e3", "maroon": "#ffafcc",
  },
  "all_hallows_eve": {
    "base": "#000000", "mantle": "#000000", "crust": "#000000",
    "surface0": "#141414", "surface1": "#242424", "surface2": "#363636",
    "overlay0": "#404040", "overlay1": "#969696", "overlay2": "#cfcfcf",
    "text": "#ffffff", "subtext0": "#ffffff", "subtext1": "#969696",
    "blue": "#3387cc", "sapphire": "#cccc33", "peach": "#ffd93d",
    "green": "#66cc33", "red": "#c83730", "mauve": "#9933cc",
    "pink": "#d0d0ff", "yellow": "#cc7833", "maroon": "#ff6b6b",
  },
  "atelier": {
    "base": "#232923", "mantle": "#202620", "crust": "#1c211c",
    "surface0": "#323731", "surface1": "#3d413c", "surface2": "#4a4d49",
    "overlay0": "#788778", "overlay1": "#a5aba2", "overlay2": "#c3c2be",
    "text": "#dcd6d6", "subtext0": "#dcd9d6", "subtext1": "#a5aba2",
    "blue": "#9eb8b5", "sapphire": "#b0c5b9", "peach": "#d9d9c9",
    "green": "#8cab8f", "red": "#c5a687", "mauve": "#c5a587",
    "pink": "#c5a487", "yellow": "#b1b195", "maroon": "#c5a687",
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
  "azure_glow": {
    "base": "#0a0f1a", "mantle": "#0d1b26", "crust": "#080c15",
    "surface0": "#17202c", "surface1": "#202c3a", "surface2": "#2b3b4a",
    "overlay0": "#123247", "overlay1": "#56809a", "overlay2": "#82b4d1",
    "text": "#a8dfff", "subtext0": "#cceeff", "subtext1": "#56809a",
    "blue": "#00aaff", "sapphire": "#66e0ff", "peach": "#66ddff",
    "green": "#00e0b8", "red": "#0099cc", "mauve": "#3399ff",
    "pink": "#66b2ff", "yellow": "#33ccff", "maroon": "#33ccff",
  },
  "batman": {
    "base": "#1b1d1e", "mantle": "#191b1c", "crust": "#161718",
    "surface0": "#262829", "surface1": "#2f3031", "surface2": "#383a3a",
    "overlay0": "#505354", "overlay1": "#777978", "overlay2": "#91938f",
    "text": "#a7a8a3", "subtext0": "#c6c5bf", "subtext1": "#777978",
    "blue": "#737174", "sapphire": "#62605f", "peach": "#feed6c",
    "green": "#c8be46", "red": "#e6dc44", "mauve": "#747271",
    "pink": "#9a9a9d", "yellow": "#f4fd22", "maroon": "#fff78e",
  },
  "batou": {
    "base": "#121212", "mantle": "#111111", "crust": "#0e0e0e",
    "surface0": "#1e1e1e", "surface1": "#262626", "surface2": "#313131",
    "overlay0": "#383735", "overlay1": "#696867", "overlay2": "#898988",
    "text": "#a4a4a4", "subtext0": "#dbd9d3", "subtext1": "#696867",
    "blue": "#605d5b", "sapphire": "#c2bbb0", "peach": "#8f4445",
    "green": "#a5a297", "red": "#e19e74", "mauve": "#8a8575",
    "pink": "#b3adad", "yellow": "#c6c4b0", "maroon": "#984b1e",
  },
  "bauhaus": {
    "base": "#101318", "mantle": "#161b22", "crust": "#0d0f13",
    "surface0": "#21252a", "surface1": "#2f3237", "surface2": "#3e4146",
    "overlay0": "#3a3f4c", "overlay1": "#898e98", "overlay2": "#bec3cb",
    "text": "#eaeff5", "subtext0": "#ffffff", "subtext1": "#898e98",
    "blue": "#8999aa", "sapphire": "#809d9e", "peach": "#e0a568",
    "green": "#789fa2", "red": "#cb886d", "mauve": "#8d758f",
    "pink": "#a3ada7", "yellow": "#e7a46f", "maroon": "#e06c55",
  },
  "biscuit_de_mar_dark": {
    "base": "#1a1515", "mantle": "#181313", "crust": "#151111",
    "surface0": "#2a2322", "surface1": "#352e2c", "surface2": "#433b38",
    "overlay0": "#725a5a", "overlay1": "#a28c86", "overlay2": "#c2ada4",
    "text": "#dcc9bc", "subtext0": "#cf223e", "subtext1": "#a28c86",
    "blue": "#614f76", "sapphire": "#756d94", "peach": "#959a6b",
    "green": "#768f80", "red": "#f07342", "mauve": "#7b3d79",
    "pink": "#7b3d79", "yellow": "#959a6b", "maroon": "#f07342",
  },
  "black_arch": {
    "base": "#000000", "mantle": "#262626", "crust": "#000000",
    "surface0": "#141414", "surface1": "#242424", "surface2": "#363636",
    "overlay0": "#262626", "overlay1": "#888888", "overlay2": "#c9c9c9",
    "text": "#ffffff", "subtext0": "#d4d4d4", "subtext1": "#888888",
    "blue": "#989898", "sapphire": "#585858", "peach": "#b9b9b9",
    "green": "#8e8e8e", "red": "#646464", "mauve": "#747474",
    "pink": "#747474", "yellow": "#b9b9b9", "maroon": "#646464",
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
  "black_sand": {
    "base": "#14181e", "mantle": "#12161c", "crust": "#101318",
    "surface0": "#23272e", "surface1": "#2e3339", "surface2": "#3b4047",
    "overlay0": "#525d6a", "overlay1": "#8a939f", "overlay2": "#afb8c2",
    "text": "#ced6e0", "subtext0": "#e9eef5", "subtext1": "#8a939f",
    "blue": "#8ea7c2", "sapphire": "#8fb5bd", "peach": "#d8cfb6",
    "green": "#89b39b", "red": "#bd8489", "mauve": "#bc9bbf",
    "pink": "#d3b9d5", "yellow": "#c3b798", "maroon": "#d2a2a6",
  },
  "bluedotrb": {
    "base": "#161616", "mantle": "#484848", "crust": "#121212",
    "surface0": "#282828", "surface1": "#353536", "surface2": "#444545",
    "overlay0": "#484848", "overlay1": "#949597", "overlay2": "#c8c9cc",
    "text": "#f2f4f8", "subtext0": "#dfdfe0", "subtext1": "#949597",
    "blue": "#be95ff", "sapphire": "#08bdba", "peach": "#25be6a",
    "green": "#4242b1", "red": "#ee5396", "mauve": "#e0e27b",
    "pink": "#e0e27b", "yellow": "#25be6a", "maroon": "#ee5396",
  },
  "blue_ridge_dark": {
    "base": "#1c2128", "mantle": "#2c3640", "crust": "#161a20",
    "surface0": "#2c3137", "surface1": "#393d42", "surface2": "#474a4f",
    "overlay0": "#4a5568", "overlay1": "#91969f", "overlay2": "#c0c2c4",
    "text": "#e8e6e3", "subtext0": "#c4b5a0", "subtext1": "#91969f",
    "blue": "#6b8cae", "sapphire": "#7ec8c8", "peach": "#f4e4bc",
    "green": "#7ea67c", "red": "#cd9575", "mauve": "#9b8aa0",
    "pink": "#b4a3ba", "yellow": "#d4af37", "maroon": "#daa89b",
  },
  "castle_on_a_lake": {
    "base": "#060606", "mantle": "#060606", "crust": "#050505",
    "surface0": "#191618", "surface1": "#272325", "surface2": "#373135",
    "overlay0": "#626262", "overlay1": "#a2959c", "overlay2": "#ccb8c4",
    "text": "#f0d4e4", "subtext0": "#f4deea", "subtext1": "#a2959c",
    "blue": "#5870a8", "sapphire": "#6090a0", "peach": "#ffd780",
    "green": "#80a070", "red": "#a06048", "mauve": "#8060a0",
    "pink": "#ae89d3", "yellow": "#d4b060", "maroon": "#d38669",
  },
  "catppuccin_mocha_dark": {
    "base": "#010101", "mantle": "#45475a", "crust": "#010101",
    "surface0": "#111214", "surface1": "#1e1f23", "surface2": "#2c2e34",
    "overlay0": "#585b70", "overlay1": "#8d92ab", "overlay2": "#b0b7d3",
    "text": "#cdd6f4", "subtext0": "#bac2de", "subtext1": "#8d92ab",
    "blue": "#89b4fa", "sapphire": "#94e2d5", "peach": "#f9e2af",
    "green": "#a6e3a1", "red": "#f38ba8", "mauve": "#f5c2e7",
    "pink": "#f5c2e7", "yellow": "#f9e2af", "maroon": "#f38ba8",
  },
  "cincinnati": {
    "base": "#101b25", "mantle": "#0f1922", "crust": "#0d161e",
    "surface0": "#212b34", "surface1": "#2d3740", "surface2": "#3b464d",
    "overlay0": "#748a9b", "overlay1": "#a4b3bc", "overlay2": "#c4cfd2",
    "text": "#dfe6e4", "subtext0": "#f4f8f7", "subtext1": "#a4b3bc",
    "blue": "#2e72ca", "sapphire": "#5b96b8", "peach": "#dccb98",
    "green": "#5a6b45", "red": "#9c6b63", "mauve": "#a98f95",
    "pink": "#c2a8ad", "yellow": "#c9b77e", "maroon": "#b98a80",
  },
  "citrus_cynapse": {
    "base": "#000000", "mantle": "#000000", "crust": "#000000",
    "surface0": "#0c0c0c", "surface1": "#141414", "surface2": "#1f1f1f",
    "overlay0": "#9bd46a", "overlay1": "#97b67c", "overlay2": "#94a288",
    "text": "#929292", "subtext0": "#80e31c", "subtext1": "#97b67c",
    "blue": "#c0df44", "sapphire": "#b1e95f", "peach": "#98d450",
    "green": "#da630d", "red": "#f6000e", "mauve": "#a6eb5d",
    "pink": "#b1e563", "yellow": "#8dee0b", "maroon": "#ff777d",
  },
  "city_783": {
    "base": "#181a1f", "mantle": "#16181d", "crust": "#131519",
    "surface0": "#25272c", "surface1": "#2f3136", "surface2": "#3a3c42",
    "overlay0": "#4b515b", "overlay1": "#7c828b", "overlay2": "#9ea3ab",
    "text": "#b9bec6", "subtext0": "#eceff2", "subtext1": "#7c828b",
    "blue": "#ad2222", "sapphire": "#8f949c", "peach": "#f04a4a",
    "green": "#dce0e6", "red": "#e53939", "mauve": "#c3c8d0",
    "pink": "#f5f7f9", "yellow": "#9e1a1a", "maroon": "#ff5c5c",
  },
  "cobalt2": {
    "base": "#122738", "mantle": "#000000", "crust": "#0e1f2d",
    "surface0": "#253848", "surface1": "#334554", "surface2": "#445462",
    "overlay0": "#0050a4", "overlay1": "#739fcd", "overlay2": "#bfd3e8",
    "text": "#ffffff", "subtext0": "#ffffff", "subtext1": "#739fcd",
    "blue": "#0088ff", "sapphire": "#80fcff", "peach": "#ffc600",
    "green": "#3ad900", "red": "#ff628c", "mauve": "#fb94ff",
    "pink": "#fb94ff", "yellow": "#ffc600", "maroon": "#ff628c",
  },
  "coffee": {
    "base": "#1d150f", "mantle": "#1b130e", "crust": "#17110c",
    "surface0": "#2e251e", "surface1": "#3b322a", "surface2": "#494038",
    "overlay0": "#8f7a67", "overlay1": "#bba996", "overlay2": "#d8c8b6",
    "text": "#f0e2d0", "subtext0": "#fff3ea", "subtext1": "#bba996",
    "blue": "#cf90a2", "sapphire": "#e8c07f", "peach": "#ffe0a0",
    "green": "#cdb878", "red": "#d78a6f", "mauve": "#ec8f89",
    "pink": "#ffa39a", "yellow": "#ffda92", "maroon": "#e8a086",
  },
  "coffee_latte": {
    "base": "#e8e3c3", "mantle": "#d5d1b3", "crust": "#bab69c",
    "surface0": "#d9d3b6", "surface1": "#cec7ac", "surface2": "#c1b9a0",
    "overlay0": "#76756f", "overlay1": "#554c4a", "overlay2": "#3f3132",
    "text": "#2d1a1d", "subtext0": "#4e373b", "subtext1": "#554c4a",
    "blue": "#8e2d53", "sapphire": "#4f6b00", "peach": "#858b00",
    "green": "#345600", "red": "#a4405e", "mauve": "#7a003b",
    "pink": "#a8275f", "yellow": "#636600", "maroon": "#d25e83",
  },
  "commit": {
    "base": "#0b0f14", "mantle": "#0a0e12", "crust": "#090c10",
    "surface0": "#142221", "surface1": "#1b312a", "surface2": "#234135",
    "overlay0": "#5c739b", "overlay1": "#6ab2a5", "overlay2": "#74dcac",
    "text": "#7cffb2", "subtext0": "#f1f1f0", "subtext1": "#6ab2a5",
    "blue": "#57c7ff", "sapphire": "#9aedfe", "peach": "#faffc8",
    "green": "#5af78e", "red": "#ff5c57", "mauve": "#ff6ac1",
    "pink": "#ff9bd6", "yellow": "#f3f99d", "maroon": "#ff8a85",
  },
  "cpunk": {
    "base": "#040303", "mantle": "#040303", "crust": "#030202",
    "surface0": "#181717", "surface1": "#272626", "surface2": "#393838",
    "overlay0": "#7f6e6e", "overlay1": "#b9afaf", "overlay2": "#dfdbdb",
    "text": "#ffffff", "subtext0": "#f3f3f3", "subtext1": "#b9afaf",
    "blue": "#aaacac", "sapphire": "#babbbb", "peach": "#fff9a3",
    "green": "#d1d2d1", "red": "#f82a2a", "mauve": "#f76e78",
    "pink": "#ffc2c7", "yellow": "#fef348", "maroon": "#ff7f7f",
  },
  "crimson_gold": {
    "base": "#300808", "mantle": "#2c0707", "crust": "#260606",
    "surface0": "#3d160b", "surface1": "#48200d", "surface2": "#532c10",
    "overlay0": "#aaaaaa", "overlay1": "#bfae72", "overlay2": "#ccb04c",
    "text": "#d8b22d", "subtext0": "#eaeaea", "subtext1": "#bfae72",
    "blue": "#e68e0d", "sapphire": "#ee0000", "peach": "#b90a0a",
    "green": "#ffdd55", "red": "#ee3333", "mauve": "#d35f5f",
    "pink": "#b91c1c", "yellow": "#b91c1c", "maroon": "#ff3333",
  },
  "darcula": {
    "base": "#2b2b2b", "mantle": "#1e1e1e", "crust": "#222222",
    "surface0": "#353637", "surface1": "#3d3f41", "surface2": "#45484c",
    "overlay0": "#5c5c5c", "overlay1": "#7f858c", "overlay2": "#96a0ac",
    "text": "#a9b7c6", "subtext0": "#ffffff", "subtext1": "#7f858c",
    "blue": "#6897bb", "sapphire": "#39b2ac", "peach": "#ffd760",
    "green": "#629755", "red": "#ff6b68", "mauve": "#9876aa",
    "pink": "#b08cbc", "yellow": "#cc7832", "maroon": "#ff938a",
  },
  "demon": {
    "base": "#0f0f0f", "mantle": "#0e0e0e", "crust": "#0c0c0c",
    "surface0": "#201f1d", "surface1": "#2c2b28", "surface2": "#3b3835",
    "overlay0": "#6b6867", "overlay1": "#a09990", "overlay2": "#c3b9ab",
    "text": "#e0d4c2", "subtext0": "#bdb5aa", "subtext1": "#a09990",
    "blue": "#5c624b", "sapphire": "#7a7d80", "peach": "#e24c00",
    "green": "#586259", "red": "#bb1c1c", "mauve": "#655e56",
    "pink": "#655e56", "yellow": "#e24c00", "maroon": "#bb1c1c",
  },
  "dotrb": {
    "base": "#121212", "mantle": "#111111", "crust": "#0e0e0e",
    "surface0": "#242424", "surface1": "#323232", "surface2": "#424242",
    "overlay0": "#949494", "overlay1": "#c0c0c0", "overlay2": "#dddddd",
    "text": "#f5f5f5", "subtext0": "#d5d5d5", "subtext1": "#c0c0c0",
    "blue": "#4a8b8b", "sapphire": "#b4b4b4", "peach": "#f0be66",
    "green": "#b14242", "red": "#d66e36", "mauve": "#a7a7a7",
    "pink": "#a7a7a7", "yellow": "#f0be66", "maroon": "#d66e36",
  },
  "dos_moos": {
    "base": "#131516", "mantle": "#111314", "crust": "#0f1112",
    "surface0": "#252626", "surface1": "#333333", "surface2": "#434241",
    "overlay0": "#3a4849", "overlay1": "#90918e", "overlay2": "#c8c2bc",
    "text": "#f8ebe3", "subtext0": "#d5dbd7", "subtext1": "#90918e",
    "blue": "#a5b5ab", "sapphire": "#6d877d", "peach": "#f4e276",
    "green": "#819890", "red": "#f0334a", "mauve": "#72856c",
    "pink": "#72856c", "yellow": "#f4e276", "maroon": "#f0334a",
  },
  "drac": {
    "base": "#101428", "mantle": "#1b1d21", "crust": "#0d1020",
    "surface0": "#222639", "surface1": "#303345", "surface2": "#3f4354",
    "overlay0": "#555555", "overlay1": "#9c9d9e", "overlay2": "#cbcccf",
    "text": "#f2f4f8", "subtext0": "#bbbbbb", "subtext1": "#9c9d9e",
    "blue": "#50fa7b", "sapphire": "#8be9fd", "peach": "#ffffa5",
    "green": "#1e90ff", "red": "#ff5555", "mauve": "#ff79c6",
    "pink": "#ff92df", "yellow": "#f1fa8c", "maroon": "#ff6e6e",
  },
  "eldritch": {
    "base": "#212337", "mantle": "#21222c", "crust": "#1a1c2c",
    "surface0": "#313447", "surface1": "#3d4152", "surface2": "#4b5060",
    "overlay0": "#21222c", "overlay1": "#7c8389", "overlay2": "#b8c4c6",
    "text": "#ebfafa", "subtext0": "#ebfafa", "subtext1": "#7c8389",
    "blue": "#9071f4", "sapphire": "#04d1f9", "peach": "#e9f941",
    "green": "#37f499", "red": "#f9515d", "mauve": "#f265b5",
    "pink": "#f265b5", "yellow": "#e9f941", "maroon": "#f9515d",
  },
  "event_horizon": {
    "base": "#1c1e26", "mantle": "#1a1c23", "crust": "#16181e",
    "surface0": "#2a2c34", "surface1": "#34373e", "surface2": "#41434a",
    "overlay0": "#6f6f70", "overlay1": "#989a9b", "overlay2": "#b4b6b8",
    "text": "#cbced0", "subtext0": "#e3e6ee", "subtext1": "#989a9b",
    "blue": "#26bbd9", "sapphire": "#59e1e3", "peach": "#fbc3a7",
    "green": "#29d398", "red": "#e95678", "mauve": "#ee64ac",
    "pink": "#f075b5", "yellow": "#fac29a", "maroon": "#ec6a88",
  },
  "evergarden": {
    "base": "#232a2e", "mantle": "#b3e6db", "crust": "#1c2225",
    "surface0": "#2e3739", "surface1": "#364042", "surface2": "#404b4c",
    "overlay0": "#adc9bc", "overlay1": "#adc9bc", "overlay2": "#adc9bc",
    "text": "#adc9bc", "subtext0": "#839e9a", "subtext1": "#adc9bc",
    "blue": "#839e9a", "sapphire": "#b3e6db", "peach": "#f5d098",
    "green": "#cbe3b3", "red": "#f57f82", "mauve": "#b3e6db",
    "pink": "#f5d098", "yellow": "#f5d098", "maroon": "#f57f82",
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
  "fireside": {
    "base": "#0a1220", "mantle": "#09111d", "crust": "#080e1a",
    "surface0": "#1c2431", "surface1": "#2a313e", "surface2": "#3a414d",
    "overlay0": "#5a606b", "overlay1": "#9ea2a9", "overlay2": "#caced2",
    "text": "#f0f2f5", "subtext0": "#ffffff", "subtext1": "#9ea2a9",
    "blue": "#b8b8b6", "sapphire": "#d0cac7", "peach": "#c8c3b8",
    "green": "#889889", "red": "#e06b58", "mauve": "#e48b7a",
    "pink": "#f0a19a", "yellow": "#b8b5a2", "maroon": "#e06b58",
  },
  "flat_dracula": {
    "base": "#282a36", "mantle": "#21222c", "crust": "#20222b",
    "surface0": "#393a45", "surface1": "#454750", "surface2": "#54555d",
    "overlay0": "#6272a4", "overlay1": "#a6aec7", "overlay2": "#d2d6de",
    "text": "#f8f8f2", "subtext0": "#ffffff", "subtext1": "#a6aec7",
    "blue": "#bd93f9", "sapphire": "#8be9fd", "peach": "#ffffa5",
    "green": "#50fa7b", "red": "#ff5555", "mauve": "#ff79c6",
    "pink": "#ff92df", "yellow": "#f1fa8c", "maroon": "#ff6e6e",
  },
  "flexoki_dark": {
    "base": "#100f0f", "mantle": "#0f0e0e", "crust": "#0d0c0c",
    "surface0": "#1f1e1d", "surface1": "#2b2a28", "surface2": "#383735",
    "overlay0": "#6f6e69", "overlay1": "#9a9992", "overlay2": "#b6b5ac",
    "text": "#cecdc3", "subtext0": "#878580", "subtext1": "#9a9992",
    "blue": "#205ea6", "sapphire": "#24837b", "peach": "#d0a215",
    "green": "#66800b", "red": "#af3029", "mauve": "#a02f6f",
    "pink": "#ce5d97", "yellow": "#ad8301", "maroon": "#d14d41",
  },
  "forest_green": {
    "base": "#0f1a14", "mantle": "#1e2a24", "crust": "#0c1510",
    "surface0": "#1b2a1f", "surface1": "#243728", "surface2": "#2f4532",
    "overlay0": "#3a4a3d", "overlay1": "#6c906a", "overlay2": "#8cbf88",
    "text": "#a8e6a1", "subtext0": "#e6e6d6", "subtext1": "#6c906a",
    "blue": "#5fa9a8", "sapphire": "#56b6c2", "peach": "#e5c07b",
    "green": "#6bbf7a", "red": "#e06c75", "mauve": "#c678dd",
    "pink": "#d19a66", "yellow": "#d7ba7d", "maroon": "#f28b82",
  },
  "frost": {
    "base": "#0a0f1c", "mantle": "#090e1a", "crust": "#080c16",
    "surface0": "#1a1f2b", "surface1": "#262b36", "surface2": "#343944",
    "overlay0": "#51545e", "overlay1": "#8c8e95", "overlay2": "#b3b5ba",
    "text": "#d4d5d9", "subtext0": "#efeff1", "subtext1": "#8c8e95",
    "blue": "#9bb0c2", "sapphire": "#b8c7d0", "peach": "#9fadb8",
    "green": "#95a8b8", "red": "#869aac", "mauve": "#a8b9c6",
    "pink": "#a8b9c6", "yellow": "#9fadb8", "maroon": "#869aac",
  },
  "fuchsblau": {
    "base": "#1a2234", "mantle": "#181f30", "crust": "#151b2a",
    "surface0": "#283043", "surface1": "#333b4e", "surface2": "#40485b",
    "overlay0": "#4e5784", "overlay1": "#8790b4", "overlay2": "#adb6d4",
    "text": "#cdd6ee", "subtext0": "#e0e8ff", "subtext1": "#8790b4",
    "blue": "#88aede", "sapphire": "#4dd6c8", "peach": "#f4b478",
    "green": "#86c79c", "red": "#e89a8a", "mauve": "#c79dc9",
    "pink": "#d7afda", "yellow": "#f0a060", "maroon": "#f0ada0",
  },
  "futurism": {
    "base": "#0a1428", "mantle": "#091225", "crust": "#081020",
    "surface0": "#1c2639", "surface1": "#2a3446", "surface2": "#3a4455",
    "overlay0": "#53627a", "overlay1": "#9aa6b6", "overlay2": "#c9d2de",
    "text": "#f0f8ff", "subtext0": "#ffffff", "subtext1": "#9aa6b6",
    "blue": "#f0f8ff", "sapphire": "#f0f8ff", "peach": "#6a90d2",
    "green": "#00bfff", "red": "#ff40a3", "mauve": "#ff40a3",
    "pink": "#ff40a3", "yellow": "#5076b2", "maroon": "#ff40a3",
  },
  "futurist": {
    "base": "#0a1624", "mantle": "#091421", "crust": "#08121d",
    "surface0": "#1b2734", "surface1": "#273441", "surface2": "#36434f",
    "overlay0": "#5e7a88", "overlay1": "#97acb8", "overlay2": "#bcced8",
    "text": "#dceaf2", "subtext0": "#eef6fa", "subtext1": "#97acb8",
    "blue": "#3a8fb0", "sapphire": "#3ec8d4", "peach": "#ffd078",
    "green": "#6bcf7a", "red": "#e07a62", "mauve": "#d06ae0",
    "pink": "#e890f0", "yellow": "#f0b84a", "maroon": "#f09078",
  },
  "gand": {
    "base": "#3a332a", "mantle": "#352f27", "crust": "#2e2922",
    "surface0": "#494238", "surface1": "#544d42", "surface2": "#615a4f",
    "overlay0": "#968872", "overlay1": "#c1b5a0", "overlay2": "#ddd3bf",
    "text": "#f5ecd9", "subtext0": "#fff6e2", "subtext1": "#c1b5a0",
    "blue": "#74accf", "sapphire": "#7dbebf", "peach": "#ebd493",
    "green": "#83baa1", "red": "#ed806b", "mauve": "#c494b9",
    "pink": "#d5afca", "yellow": "#dab46b", "maroon": "#ee9881",
  },
  "ghost_pastel": {
    "base": "#070506", "mantle": "#060506", "crust": "#060405",
    "surface0": "#1b191a", "surface1": "#2a2829", "surface2": "#3b3a3a",
    "overlay0": "#836f79", "overlay1": "#bbb0b5", "overlay2": "#e0dbde",
    "text": "#ffffff", "subtext0": "#d9b6fd", "subtext1": "#bbb0b5",
    "blue": "#979fec", "sapphire": "#7c93dd", "peach": "#f6dbe6",
    "green": "#648ed0", "red": "#b37580", "mauve": "#cd9dcf",
    "pink": "#eddaee", "yellow": "#e095b5", "maroon": "#d5aeb5",
  },
  "gold_rush": {
    "base": "#121212", "mantle": "#76520e", "crust": "#0e0e0e",
    "surface0": "#222222", "surface1": "#2e2e2e", "surface2": "#3c3c3c",
    "overlay0": "#805b10", "overlay1": "#a8946a", "overlay2": "#c3baa7",
    "text": "#d9d9d9", "subtext0": "#edc531", "subtext1": "#a8946a",
    "blue": "#926c15", "sapphire": "#805b10", "peach": "#ffee69",
    "green": "#a47e1b", "red": "#dbb42c", "mauve": "#b69121",
    "pink": "#c9a227", "yellow": "#fad643", "maroon": "#edc531",
  },
  "golden_brown": {
    "base": "#0f0b05", "mantle": "#0e0a05", "crust": "#0c0904",
    "surface0": "#1d180f", "surface1": "#282117", "surface2": "#352c1f",
    "overlay0": "#57462c", "overlay1": "#887353", "overlay2": "#a8906d",
    "text": "#c3a983", "subtext0": "#231b0e", "subtext1": "#887353",
    "blue": "#c3a983", "sapphire": "#dec8a7", "peach": "#dec8a7",
    "green": "#dec8a7", "red": "#a88c62", "mauve": "#a88c62",
    "pink": "#a88c62", "yellow": "#dec8a7", "maroon": "#a88c62",
  },
  "the_greek": {
    "base": "#d0d0c8", "mantle": "#bfbfb8", "crust": "#a6a6a0",
    "surface0": "#c2c2bb", "surface1": "#b8b8b1", "surface2": "#acaca6",
    "overlay0": "#6b7360", "overlay1": "#4b4f45", "overlay2": "#363833",
    "text": "#242424", "subtext0": "#383835", "subtext1": "#4b4f45",
    "blue": "#de6a41", "sapphire": "#6b1f2f", "peach": "#51573b",
    "green": "#2e3125", "red": "#db0030", "mauve": "#43432b",
    "pink": "#43432b", "yellow": "#51573b", "maroon": "#db0030",
  },
  "greek_noir": {
    "base": "#171717", "mantle": "#151515", "crust": "#121212",
    "surface0": "#252626", "surface1": "#303131", "surface2": "#3d3e3e",
    "overlay0": "#525252", "overlay1": "#898b8a", "overlay2": "#aeb0b0",
    "text": "#ccd0cf", "subtext0": "#a6ada6", "subtext1": "#898b8a",
    "blue": "#88a57d", "sapphire": "#7b837b", "peach": "#757864",
    "green": "#f25623", "red": "#aeab94", "mauve": "#f56e0f",
    "pink": "#f56e0f", "yellow": "#757864", "maroon": "#aeab94",
  },
  "green_garden": {
    "base": "#1d271f", "mantle": "#3c483a", "crust": "#171f19",
    "surface0": "#2e372e", "surface1": "#3b4339", "surface2": "#4a5146",
    "overlay0": "#6b7b69", "overlay1": "#a9af9c", "overlay2": "#d2d1be",
    "text": "#f5eeda", "subtext0": "#ffffff", "subtext1": "#a9af9c",
    "blue": "#649ed3", "sapphire": "#a0f0e8", "peach": "#ffd694",
    "green": "#95b86f", "red": "#d96f6f", "mauve": "#f09d73",
    "pink": "#ffb394", "yellow": "#e8b36f", "maroon": "#ff8787",
  },
  "gruvbox_material": {
    "base": "#282828", "mantle": "#252525", "crust": "#202020",
    "surface0": "#363431", "surface1": "#403d38", "surface2": "#4c4840",
    "overlay0": "#928374", "overlay1": "#b09e84", "overlay2": "#c4af8f",
    "text": "#d4be98", "subtext0": "#ddc7a1", "subtext1": "#b09e84",
    "blue": "#7daea3", "sapphire": "#89b482", "peach": "#d8a657",
    "green": "#a9b665", "red": "#ea6962", "mauve": "#d3869b",
    "pink": "#d3869b", "yellow": "#d8a657", "maroon": "#ea6962",
  },
  "harbor": {
    "base": "#dfe4c4", "mantle": "#cdd2b4", "crust": "#b2b69d",
    "surface0": "#cfd5b8", "surface1": "#c4caae", "surface2": "#b6bea3",
    "overlay0": "#7d8794", "overlay1": "#515e63", "overlay2": "#344443",
    "text": "#1c2d28", "subtext0": "#384f54", "subtext1": "#515e63",
    "blue": "#4c6c94", "sapphire": "#3d727d", "peach": "#dc8164",
    "green": "#556753", "red": "#b14752", "mauve": "#8a5b81",
    "pink": "#8a5b81", "yellow": "#dc8164", "maroon": "#b14752",
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
  "hinterlands": {
    "base": "#222222", "mantle": "#1f1f1f", "crust": "#1b1b1b",
    "surface0": "#343434", "surface1": "#414141", "surface2": "#505050",
    "overlay0": "#525252", "overlay1": "#a0a0a0", "overlay2": "#d4d4d4",
    "text": "#ffffff", "subtext0": "#b9b9b9", "subtext1": "#a0a0a0",
    "blue": "#686868", "sapphire": "#868686", "peach": "#a0a0a0",
    "green": "#8b8b8b", "red": "#7c7c7c", "mauve": "#747474",
    "pink": "#747474", "yellow": "#a0a0a0", "maroon": "#7c7c7c",
  },
  "infernium": {
    "base": "#1c1c1c", "mantle": "#1a1a1a", "crust": "#161616",
    "surface0": "#2c2c2c", "surface1": "#373737", "surface2": "#454545",
    "overlay0": "#767476", "overlay1": "#a6a5a6", "overlay2": "#c6c5c6",
    "text": "#e0e0e0", "subtext0": "#ffffff", "subtext1": "#a6a5a6",
    "blue": "#aeb1c0", "sapphire": "#e99867", "peach": "#ffe39a",
    "green": "#767476", "red": "#d66938", "mauve": "#ba6435",
    "pink": "#e99867", "yellow": "#f7d383", "maroon": "#e3884a",
  },
  "inky_pinky": {
    "base": "#13131d", "mantle": "#11111b", "crust": "#0f0f17",
    "surface0": "#21212b", "surface1": "#2c2c35", "surface2": "#393941",
    "overlay0": "#434353", "overlay1": "#7f7f88", "overlay2": "#a7a7ab",
    "text": "#c8c8c8", "subtext0": "#a1a2a7", "subtext1": "#7f7f88",
    "blue": "#7c7ca8", "sapphire": "#919ab7", "peach": "#e3aebf",
    "green": "#a6b2c7", "red": "#ea90a8", "mauve": "#9f859f",
    "pink": "#bfadbf", "yellow": "#d18ba2", "maroon": "#f6bfce",
  },
  "japan_night": {
    "base": "#0b1b2b", "mantle": "#0a1928", "crust": "#091622",
    "surface0": "#192735", "surface1": "#23313c", "surface2": "#303c45",
    "overlay0": "#294857", "overlay1": "#6a7a7b", "overlay2": "#959a93",
    "text": "#b9b6a7", "subtext0": "#d4d1c2", "subtext1": "#6a7a7b",
    "blue": "#2b5e8f", "sapphire": "#638f92", "peach": "#7b8a65",
    "green": "#708c8b", "red": "#b9968f", "mauve": "#886a64",
    "pink": "#8c6760", "yellow": "#7b8768", "maroon": "#be928a",
  },
  "lamplight": {
    "base": "#151515", "mantle": "#131313", "crust": "#111111",
    "surface0": "#262626", "surface1": "#323232", "surface2": "#414141",
    "overlay0": "#7a7a75", "overlay1": "#ababa8", "overlay2": "#ccccca",
    "text": "#e7e7e7", "subtext0": "#f1f1e8", "subtext1": "#ababa8",
    "blue": "#648ad8", "sapphire": "#1fb5bc", "peach": "#e0ab57",
    "green": "#78bd74", "red": "#d76563", "mauve": "#be80ca",
    "pink": "#d89ce4", "yellow": "#c68f32", "maroon": "#f2827e",
  },
  "lawson_night": {
    "base": "#1e1e2e", "mantle": "#1c1c2a", "crust": "#181825",
    "surface0": "#2c2d3e", "surface1": "#36384a", "surface2": "#434558",
    "overlay0": "#45475a", "overlay1": "#82879f", "overlay2": "#abb2ce",
    "text": "#cdd6f4", "subtext0": "#dae0f7", "subtext1": "#82879f",
    "blue": "#89b4fa", "sapphire": "#94e2d5", "peach": "#f9e2af",
    "green": "#a6e3a1", "red": "#f38ba8", "mauve": "#cba6f7",
    "pink": "#cba6f7", "yellow": "#f9e2af", "maroon": "#f38ba8",
  },
  "map_quest": {
    "base": "#ecd3a1", "mantle": "#d9c294", "crust": "#bda981",
    "surface0": "#dec89a", "surface1": "#d3bf94", "surface2": "#c7b68e",
    "overlay0": "#b79f70", "overlay1": "#80775e", "overlay2": "#5b5d51",
    "text": "#3c4747", "subtext0": "#121515", "subtext1": "#80775e",
    "blue": "#1c2121", "sapphire": "#7b826d", "peach": "#b59d71",
    "green": "#3a443d", "red": "#4f351e", "mauve": "#764e27",
    "pink": "#c17c38", "yellow": "#826e48", "maroon": "#966133",
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
  "matrix": {
    "base": "#080c09", "mantle": "#070b08", "crust": "#060a07",
    "surface0": "#121b13", "surface1": "#1a261b", "surface2": "#243425",
    "overlay0": "#678d6a", "overlay1": "#77a879", "overlay2": "#82ba84",
    "text": "#8bc98c", "subtext0": "#c5e6c6", "subtext1": "#77a879",
    "blue": "#3d8f68", "sapphire": "#4bb56a", "peach": "#d4d66a",
    "green": "#2d9a48", "red": "#d15d57", "mauve": "#708b6d",
    "pink": "#7a927a", "yellow": "#b8ba48", "maroon": "#e97870",
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
  "midnight": {
    "base": "#000000", "mantle": "#333333", "crust": "#000000",
    "surface0": "#131313", "surface1": "#212121", "surface2": "#323232",
    "overlay0": "#8a8a8d", "overlay1": "#b7b7b9", "overlay2": "#d6d6d6",
    "text": "#efefef", "subtext0": "#bebebe", "subtext1": "#b7b7b9",
    "blue": "#e68e0d", "sapphire": "#bebebe", "peach": "#b90a0a",
    "green": "#ffc107", "red": "#d35f5f", "mauve": "#d35f5f",
    "pink": "#b91c1c", "yellow": "#b91c1c", "maroon": "#b91c1c",
  },
  "milky_matcha": {
    "base": "#f4f1e8", "mantle": "#e8e2d5", "crust": "#c3c1ba",
    "surface0": "#e8e6dc", "surface1": "#dfded3", "surface2": "#d4d5c9",
    "overlay0": "#d6ccb9", "overlay1": "#9fa08b", "overlay2": "#7a826c",
    "text": "#5c6a53", "subtext0": "#8b7355", "subtext1": "#9fa08b",
    "blue": "#7a92a5", "sapphire": "#6fa695", "peach": "#e6bb8a",
    "green": "#7a9461", "red": "#c65f5f", "mauve": "#a17a8f",
    "pink": "#b892a5", "yellow": "#d4a574", "maroon": "#d67b7b",
  },
  "mini_jcw": {
    "base": "#0b0b0d", "mantle": "#0a0a0c", "crust": "#09090a",
    "surface0": "#1b1b1d", "surface1": "#28282a", "surface2": "#363638",
    "overlay0": "#3c3c40", "overlay1": "#828285", "overlay2": "#b1b1b4",
    "text": "#d8d8da", "subtext0": "#f6f6f8", "subtext1": "#828285",
    "blue": "#3a4658", "sapphire": "#8a9aa8", "peach": "#e0c04a",
    "green": "#2f6b4f", "red": "#c8102e", "mauve": "#9a2438",
    "pink": "#c44a5c", "yellow": "#c9a227", "maroon": "#e31c3d",
  },
  "moodpeak": {
    "base": "#181c22", "mantle": "#161a1f", "crust": "#13161b",
    "surface0": "#282c32", "surface1": "#34383e", "surface2": "#42464d",
    "overlay0": "#3d4455", "overlay1": "#868d99", "overlay2": "#b7bec7",
    "text": "#e0e6ed", "subtext0": "#d1d7e0", "subtext1": "#868d99",
    "blue": "#6a85ff", "sapphire": "#c9aff0", "peach": "#b388eb",
    "green": "#4ecdc4", "red": "#ff7b92", "mauve": "#b388eb",
    "pink": "#d1b3ff", "yellow": "#82eeff", "maroon": "#ff9ead",
  },
  "nagai_poolside": {
    "base": "#0f1b22", "mantle": "#0b141a", "crust": "#0c161b",
    "surface0": "#202c33", "surface1": "#2d393f", "surface2": "#3c484e",
    "overlay0": "#2a4652", "overlay1": "#7f939b", "overlay2": "#b7c6cc",
    "text": "#e6f1f4", "subtext0": "#ffffff", "subtext1": "#7f939b",
    "blue": "#2295d9", "sapphire": "#3a9fb7", "peach": "#f4e2b7",
    "green": "#7ca348", "red": "#ff6b6b", "mauve": "#58afd8",
    "pink": "#58afd8", "yellow": "#eed59a", "maroon": "#ff8a8a",
  },
  "naysayer": {
    "base": "#072626", "mantle": "#062323", "crust": "#061e1e",
    "surface0": "#17312e", "surface1": "#243a34", "surface2": "#32443c",
    "overlay0": "#504038", "overlay1": "#8b755e", "overlay2": "#b29878",
    "text": "#d3b58d", "subtext0": "#ffffff", "subtext1": "#8b755e",
    "blue": "#add8e6", "sapphire": "#add8e6", "peach": "#ffff00",
    "green": "#90ee90", "red": "#800000", "mauve": "#c8d4ec",
    "pink": "#f6779f", "yellow": "#8fbc8f", "maroon": "#ff0000",
  },
  "neo_sploosh": {
    "base": "#212226", "mantle": "#282828", "crust": "#1a1b1e",
    "surface0": "#323336", "surface1": "#3f3f43", "surface2": "#4d4e51",
    "overlay0": "#595959", "overlay1": "#9f9f9f", "overlay2": "#cdcdcd",
    "text": "#f4f4f4", "subtext0": "#e9e9e9", "subtext1": "#9f9f9f",
    "blue": "#008dc9", "sapphire": "#33acde", "peach": "#b0db90",
    "green": "#92bf38", "red": "#893151", "mauve": "#48b7e7",
    "pink": "#48b7e7", "yellow": "#a4d149", "maroon": "#a35b78",
  },
  "neon_dusk": {
    "base": "#16122a", "mantle": "#141127", "crust": "#120e22",
    "surface0": "#252039", "surface1": "#302b45", "surface2": "#3d3852",
    "overlay0": "#3a3154", "overlay1": "#7d7497", "overlay2": "#aaa2c3",
    "text": "#cfc7e8", "subtext0": "#f0eaff", "subtext1": "#7d7497",
    "blue": "#7b8ff2", "sapphire": "#5cc8f5", "peach": "#ffd894",
    "green": "#4be09a", "red": "#f2596c", "mauve": "#c77df5",
    "pink": "#dca5ff", "yellow": "#eec06a", "maroon": "#ff7c88",
  },
  "neovoid": {
    "base": "#000000", "mantle": "#000000", "crust": "#000000",
    "surface0": "#121212", "surface1": "#1f1f1f", "surface2": "#2f2f2f",
    "overlay0": "#1a1a1a", "overlay1": "#737373", "overlay2": "#aeaeae",
    "text": "#e0e0e0", "subtext0": "#ffffff", "subtext1": "#737373",
    "blue": "#00bfff", "sapphire": "#00bfff", "peach": "#1e90ff",
    "green": "#00bfff", "red": "#ff0040", "mauve": "#1e90ff",
    "pink": "#1e90ff", "yellow": "#1e90ff", "maroon": "#ff0040",
  },
  "neptune_blue": {
    "base": "#0b1012", "mantle": "#0a0f11", "crust": "#090d0e",
    "surface0": "#1a1f22", "surface1": "#252b2d", "surface2": "#33383b",
    "overlay0": "#3a4e56", "overlay1": "#7a888f", "overlay2": "#a4b0b4",
    "text": "#c8d0d4", "subtext0": "#eef2f3", "subtext1": "#7a888f",
    "blue": "#6a8f9a", "sapphire": "#7aadc0", "peach": "#d8c080",
    "green": "#4a7a68", "red": "#c45a4a", "mauve": "#5a6a88",
    "pink": "#7a8aa4", "yellow": "#c4a86a", "maroon": "#e07060",
  },
  "nes": {
    "base": "#101010", "mantle": "#0f0f0f", "crust": "#0d0d0d",
    "surface0": "#1f1f1f", "surface1": "#2b2b2a", "surface2": "#383837",
    "overlay0": "#525351", "overlay1": "#8a8b87", "overlay2": "#afb0ab",
    "text": "#cecfc9", "subtext0": "#e7e7e4", "subtext1": "#8a8b87",
    "blue": "#9a9d9a", "sapphire": "#9a9d9a", "peach": "#cecfc9",
    "green": "#9a9d9a", "red": "#d93f37", "mauve": "#d93f37",
    "pink": "#da0f0f", "yellow": "#9a9d9a", "maroon": "#da0f0f",
  },
  "noir": {
    "base": "#000000", "mantle": "#1c1c1c", "crust": "#000000",
    "surface0": "#0f0f0f", "surface1": "#1b1b1b", "surface2": "#292929",
    "overlay0": "#505050", "overlay1": "#838383", "overlay2": "#a5a5a5",
    "text": "#c1c1c1", "subtext0": "#ffffff", "subtext1": "#838383",
    "blue": "#aaaaaa", "sapphire": "#aa9988", "peach": "#888888",
    "green": "#c1c1c1", "red": "#8a9a7b", "mauve": "#999999",
    "pink": "#999999", "yellow": "#888888", "maroon": "#8a9a7b",
  },
  "oligarchy": {
    "base": "#0b1020", "mantle": "#0a0f1d", "crust": "#090d1a",
    "surface0": "#1d2231", "surface1": "#2a2f3e", "surface2": "#393f4d",
    "overlay0": "#65718a", "overlay1": "#a0a9bb", "overlay2": "#c7cfdb",
    "text": "#e8eef6", "subtext0": "#f7fbff", "subtext1": "#a0a9bb",
    "blue": "#4ba3c7", "sapphire": "#55d8ff", "peach": "#ffe39a",
    "green": "#9fe870", "red": "#ff6b6b", "mauve": "#b78cff",
    "pink": "#d7c2ff", "yellow": "#f4c95d", "maroon": "#ff9696",
  },
  "nujabes": {
    "base": "#0d0a11", "mantle": "#0c0910", "crust": "#0a080e",
    "surface0": "#1e1b21", "surface1": "#2b272d", "surface2": "#3a363b",
    "overlay0": "#6b5268", "overlay1": "#a1909b", "overlay2": "#c5babe",
    "text": "#e3dcda", "subtext0": "#fdf7f7", "subtext1": "#a1909b",
    "blue": "#6d4fd0", "sapphire": "#7fa8b0", "peach": "#f2e06a",
    "green": "#9aa06b", "red": "#c56e6f", "mauve": "#dc7fcc",
    "pink": "#e79ad8", "yellow": "#e0c25a", "maroon": "#dd8189",
  },
  "omacarchy": {
    "base": "#1c1c1e", "mantle": "#1a1a1c", "crust": "#161618",
    "surface0": "#2e2e30", "surface1": "#3c3c3e", "surface2": "#4c4c4d",
    "overlay0": "#2c2c2e", "overlay1": "#8b8b8c", "overlay2": "#cacacb",
    "text": "#ffffff", "subtext0": "#f2f2f2", "subtext1": "#8b8b8c",
    "blue": "#7a7a7a", "sapphire": "#9a9a9a", "peach": "#777777",
    "green": "#5a5a5a", "red": "#4a4a4a", "mauve": "#8a8a8a",
    "pink": "#999999", "yellow": "#6a6a6a", "maroon": "#555555",
  },
  "omaled": {
    "base": "#000000", "mantle": "#000000", "crust": "#000000",
    "surface0": "#120808", "surface1": "#200d0e", "surface2": "#301415",
    "overlay0": "#5a000b", "overlay1": "#992b33", "overlay2": "#c3484d",
    "text": "#e66063", "subtext0": "#f6cacc", "subtext1": "#992b33",
    "blue": "#ac1c1e", "sapphire": "#ec8385", "peach": "#f6cacc",
    "green": "#bd1f21", "red": "#dd2c2f", "mauve": "#f1a7a9",
    "pink": "#f6cacc", "yellow": "#e66063", "maroon": "#ff0022",
  },
  "one_dark": {
    "base": "#282c34", "mantle": "#252830", "crust": "#20232a",
    "surface0": "#32373f", "surface1": "#3a3f47", "surface2": "#444851",
    "overlay0": "#5c6370", "overlay1": "#808794", "overlay2": "#979eab",
    "text": "#abb2bf", "subtext0": "#dcdfe4", "subtext1": "#808794",
    "blue": "#61afef", "sapphire": "#56b6c2", "peach": "#f0d399",
    "green": "#98c379", "red": "#e06c75", "mauve": "#c678dd",
    "pink": "#d68fe8", "yellow": "#e5c07b", "maroon": "#ff7b86",
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
  "oxo_carbon": {
    "base": "#161616", "mantle": "#141414", "crust": "#121212",
    "surface0": "#282828", "surface1": "#353536", "surface2": "#444545",
    "overlay0": "#525252", "overlay1": "#9a9b9d", "overlay2": "#caccce",
    "text": "#f2f4f8", "subtext0": "#08bdba", "subtext1": "#9a9b9d",
    "blue": "#42be65", "sapphire": "#ff7eb6", "peach": "#be95ff",
    "green": "#33b1ff", "red": "#3ddbd9", "mauve": "#be95ff",
    "pink": "#ffffff", "yellow": "#ee5396", "maroon": "#78a9ff",
  },
  "pagan": {
    "base": "#0a0a0a", "mantle": "#090909", "crust": "#080808",
    "surface0": "#1d1d1d", "surface1": "#2a2a2a", "surface2": "#3b3b3b",
    "overlay0": "#6e6e6e", "overlay1": "#a9a9a9", "overlay2": "#d1d1d1",
    "text": "#f2f2f2", "subtext0": "#ffffff", "subtext1": "#a9a9a9",
    "blue": "#25aff4", "sapphire": "#47cfeb", "peach": "#e0cc95",
    "green": "#63aa87", "red": "#de443e", "mauve": "#ae83bd",
    "pink": "#c8a5d3", "yellow": "#c9ae6d", "maroon": "#ef6b62",
  },
  "pandora": {
    "base": "#0a0a0c", "mantle": "#09090b", "crust": "#08080a",
    "surface0": "#171819", "surface1": "#222223", "surface2": "#2d2e2f",
    "overlay0": "#363638", "overlay1": "#6e6f6f", "overlay2": "#939594",
    "text": "#b2b5b3", "subtext0": "#e7e7e7", "subtext1": "#6e6f6f",
    "blue": "#7aa2f7", "sapphire": "#4abaaf", "peach": "#e0af68",
    "green": "#9ece6a", "red": "#f7768e", "mauve": "#bb9af7",
    "pink": "#bb9af7", "yellow": "#e0af68", "maroon": "#f7768e",
  },
  "periphery": {
    "base": "#060f12", "mantle": "#060e11", "crust": "#050c0e",
    "surface0": "#131d20", "surface1": "#1d282a", "surface2": "#283436",
    "overlay0": "#5c7876", "overlay1": "#7f9897", "overlay2": "#96aead",
    "text": "#a9c0bf", "subtext0": "#e0efec", "subtext1": "#7f9897",
    "blue": "#6f9cb5", "sapphire": "#7fc9c4", "peach": "#dcb684",
    "green": "#7fae8e", "red": "#d4644a", "mauve": "#b587a0",
    "pink": "#cba0b8", "yellow": "#c9a06a", "maroon": "#e87a5e",
  },
  "pina": {
    "base": "#171a18", "mantle": "#151816", "crust": "#121513",
    "surface0": "#262927", "surface1": "#313432", "surface2": "#3f4140",
    "overlay0": "#595b5a", "overlay1": "#909291", "overlay2": "#b5b6b6",
    "text": "#d4d5d5", "subtext0": "#eeeeee", "subtext1": "#909291",
    "blue": "#7dd2b8", "sapphire": "#c5e8c5", "peach": "#f2e590",
    "green": "#b8c082", "red": "#d47c6b", "mauve": "#b5c9a4",
    "pink": "#c8dab8", "yellow": "#e0d480", "maroon": "#e89584",
  },
  "pink_blood": {
    "base": "#050007", "mantle": "#050006", "crust": "#040006",
    "surface0": "#180a13", "surface1": "#26121b", "surface2": "#371a25",
    "overlay0": "#a85869", "overlay1": "#c9697e", "overlay2": "#df748c",
    "text": "#f17e97", "subtext0": "#f17e97", "subtext1": "#c9697e",
    "blue": "#e80f3e", "sapphire": "#f00f40", "peach": "#ce0d3c",
    "green": "#af0b39", "red": "#8f0936", "mauve": "#d40d40",
    "pink": "#d40d40", "yellow": "#ce0d3c", "maroon": "#8f0936",
  },
  "pulsar": {
    "base": "#0a0314", "mantle": "#090312", "crust": "#080210",
    "surface0": "#1b1527", "surface1": "#282335", "surface2": "#373345",
    "overlay0": "#aa5abc", "overlay1": "#c299da", "overlay2": "#d2c3ee",
    "text": "#e0e6ff", "subtext0": "#ffffff", "subtext1": "#c299da",
    "blue": "#3298fa", "sapphire": "#3df2f2", "peach": "#ffff4d",
    "green": "#5cb960", "red": "#e53e61", "mauve": "#b82aff",
    "pink": "#d25dff", "yellow": "#f2e42e", "maroon": "#ff5779",
  },
  "purple_moon": {
    "base": "#020007", "mantle": "#020006", "crust": "#020006",
    "surface0": "#16141b", "surface1": "#25242a", "surface2": "#37363b",
    "overlay0": "#9c6cd0", "overlay1": "#c9aee5", "overlay2": "#e6daf3",
    "text": "#ffffff", "subtext0": "#dfd0f0", "subtext1": "#c9aee5",
    "blue": "#9b49c8", "sapphire": "#b895dd", "peach": "#cb97df",
    "green": "#643aad", "red": "#37277d", "mauve": "#9865cf",
    "pink": "#cdb5e8", "yellow": "#9845c6", "maroon": "#5b43cd",
  },
  "purplewave": {
    "base": "#121212", "mantle": "#ff9acb", "crust": "#0e0e0e",
    "surface0": "#221e21", "surface1": "#2e282c", "surface2": "#3b3239",
    "overlay0": "#ff9acb", "overlay1": "#eda2cc", "overlay2": "#e1a8cc",
    "text": "#d7accd", "subtext0": "#dfdfdf", "subtext1": "#eda2cc",
    "blue": "#7ea7c9", "sapphire": "#8adb8a", "peach": "#ca2edc",
    "green": "#8673d4", "red": "#ff4da6", "mauve": "#b683c3",
    "pink": "#b683c3", "yellow": "#ca2edc", "maroon": "#ff4da6",
  },
  "quattrocento_light": {
    "base": "#f0e6d3", "mantle": "#ddd4c2", "crust": "#c0b8a9",
    "surface0": "#e1d7c4", "surface1": "#d6ccb9", "surface2": "#c8beac",
    "overlay0": "#8a7a5e", "overlay1": "#635640", "overlay2": "#493d2c",
    "text": "#33291b", "subtext0": "#1c150c", "subtext1": "#635640",
    "blue": "#3f5378", "sapphire": "#3a6367", "peach": "#6d4e0c",
    "green": "#3f6b4a", "red": "#a32d2a", "mauve": "#8c3a58",
    "pink": "#752f49", "yellow": "#7d5a10", "maroon": "#8e2622",
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
  "red_monarch": {
    "base": "#191414", "mantle": "#171212", "crust": "#141010",
    "surface0": "#2b2526", "surface1": "#393233", "surface2": "#494143",
    "overlay0": "#2a2025", "overlay1": "#8a7b81", "overlay2": "#cab8bf",
    "text": "#ffeaf2", "subtext0": "#ffeaf2", "subtext1": "#8a7b81",
    "blue": "#ff6f9b", "sapphire": "#f88ab0", "peach": "#ffd1df",
    "green": "#d93665", "red": "#f1396d", "mauve": "#f1396d",
    "pink": "#ff5f91", "yellow": "#ffb3ca", "maroon": "#ff4d80",
  },
  "red_pill": {
    "base": "#050b07", "mantle": "#050a06", "crust": "#040906",
    "surface0": "#151e17", "surface1": "#202c24", "surface2": "#2e3c32",
    "overlay0": "#2c5138", "overlay1": "#729b7e", "overlay2": "#a1ccad",
    "text": "#c8f5d4", "subtext0": "#e8fff0", "subtext1": "#729b7e",
    "blue": "#3f6f9e", "sapphire": "#2fd6a8", "peach": "#ffdf7a",
    "green": "#00d94a", "red": "#ff4d2e", "mauve": "#a16fb0",
    "pink": "#c496d4", "yellow": "#f7c948", "maroon": "#ff6f4d",
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
  "ristretto_light": {
    "base": "#fdf6ee", "mantle": "#7a6550", "crust": "#cac5be",
    "surface0": "#ebe5dd", "surface1": "#ded8d1", "surface2": "#cfc9c2",
    "overlay0": "#a09080", "overlay1": "#675e53", "overlay2": "#423d36",
    "text": "#22211d", "subtext0": "#24201d", "subtext1": "#675e53",
    "blue": "#5e8e28", "sapphire": "#3d6b52", "peach": "#6b5237",
    "green": "#29472a", "red": "#df2b0d", "mauve": "#28473f",
    "pink": "#28463c", "yellow": "#8a6c3e", "maroon": "#e03c20",
  },
  "robzee84": {
    "base": "#000000", "mantle": "#262335", "crust": "#000000",
    "surface0": "#141414", "surface1": "#242424", "surface2": "#363636",
    "overlay0": "#495495", "overlay1": "#9ba1c5", "overlay2": "#d2d4e4",
    "text": "#ffffff", "subtext0": "#ffffff", "subtext1": "#9ba1c5",
    "blue": "#03edf9", "sapphire": "#03edf9", "peach": "#fede5d",
    "green": "#72f1b8", "red": "#fe4450", "mauve": "#ff7edb",
    "pink": "#ff7edb", "yellow": "#f3e70f", "maroon": "#fe4450",
  },
  "rose_pine_dark": {
    "base": "#191724", "mantle": "#171521", "crust": "#14121d",
    "surface0": "#292735", "surface1": "#353341", "surface2": "#434150",
    "overlay0": "#6e6a86", "overlay1": "#a19eb8", "overlay2": "#c4c1d8",
    "text": "#e0def4", "subtext0": "#e0def4", "subtext1": "#a19eb8",
    "blue": "#9ccfd8", "sapphire": "#ebbcba", "peach": "#f6c177",
    "green": "#31748f", "red": "#eb6f92", "mauve": "#c4a7e7",
    "pink": "#c4a7e7", "yellow": "#f6c177", "maroon": "#eb6f92",
  },
  "rose_pine_moon": {
    "base": "#232136", "mantle": "#201e32", "crust": "#1c1a2b",
    "surface0": "#323045", "surface1": "#3d3b51", "surface2": "#4b495e",
    "overlay0": "#56526e", "overlay1": "#9491aa", "overlay2": "#bebbd2",
    "text": "#e0def4", "subtext0": "#e0def4", "subtext1": "#9491aa",
    "blue": "#9ccfd8", "sapphire": "#ea9a97", "peach": "#f6c177",
    "green": "#3e8fb0", "red": "#eb6f92", "mauve": "#c4a7e7",
    "pink": "#c4a7e7", "yellow": "#f6c177", "maroon": "#eb6f92",
  },
  "rose_of_dune": {
    "base": "#f5e6d3", "mantle": "#e1d4c2", "crust": "#c4b8a9",
    "surface0": "#e6d7c5", "surface1": "#dacdbb", "surface2": "#cdc0b0",
    "overlay0": "#c8ac86", "overlay1": "#86745d", "overlay2": "#5a4f41",
    "text": "#35302a", "subtext0": "#a94a34", "subtext1": "#86745d",
    "blue": "#76634c", "sapphire": "#713a56", "peach": "#694c45",
    "green": "#9e4f5b", "red": "#a02b16", "mauve": "#78292e",
    "pink": "#78292e", "yellow": "#644535", "maroon": "#a02b16",
  },
  "ryu": {
    "base": "#050505", "mantle": "#050505", "crust": "#040404",
    "surface0": "#161514", "surface1": "#222120", "surface2": "#31302d",
    "overlay0": "#404040", "overlay1": "#84817c", "overlay2": "#b0aca4",
    "text": "#d6d0c5", "subtext0": "#fff9ed", "subtext1": "#84817c",
    "blue": "#75897f", "sapphire": "#717c7c", "peach": "#8b9388",
    "green": "#8b9388", "red": "#da614e", "mauve": "#c2a46d",
    "pink": "#c2a46d", "yellow": "#51605b", "maroon": "#df6124",
  },
  "sakura": {
    "base": "#0d0509", "mantle": "#0c0508", "crust": "#0a0407",
    "surface0": "#1f171b", "surface1": "#2d2529", "surface2": "#3d3539",
    "overlay0": "#7a5c66", "overlay1": "#af9ca3", "overlay2": "#d2c6cb",
    "text": "#f0eaed", "subtext0": "#ffffff", "subtext1": "#af9ca3",
    "blue": "#d9a56c", "sapphire": "#e8c099", "peach": "#e6ba94",
    "green": "#f29b9a", "red": "#e85f6f", "mauve": "#d1b399",
    "pink": "#e3c5ab", "yellow": "#d4a882", "maroon": "#ff7a8a",
  },
  "sakura_mochi": {
    "base": "#0b0d11", "mantle": "#0a0c10", "crust": "#090a0e",
    "surface0": "#1d1b20", "surface1": "#2b252b", "surface2": "#3b3138",
    "overlay0": "#678270", "overlay1": "#a59a98", "overlay2": "#ceaab4",
    "text": "#f0b7ca", "subtext0": "#fff1f6", "subtext1": "#a59a98",
    "blue": "#67dd82", "sapphire": "#6f9485", "peach": "#e6d3b4",
    "green": "#5aa15d", "red": "#f23888", "mauve": "#f0b7ca",
    "pink": "#ffd0dc", "yellow": "#d7be96", "maroon": "#ff6aa7",
  },
  "saga": {
    "base": "#05080a", "mantle": "#050709", "crust": "#040608",
    "surface0": "#191b1e", "surface1": "#28292c", "surface2": "#3a3a3d",
    "overlay0": "#4b4c4d", "overlay1": "#9c989d", "overlay2": "#d2ccd2",
    "text": "#fff6ff", "subtext0": "#f3ceff", "subtext1": "#9c989d",
    "blue": "#b2fff3", "sapphire": "#ffc79b", "peach": "#fff6c3",
    "green": "#baf7b5", "red": "#ff9fbc", "mauve": "#dfbaff",
    "pink": "#dfbaff", "yellow": "#fff6c3", "maroon": "#ffaecb",
  },
  "sapphire": {
    "base": "#060d1f", "mantle": "#060c1d", "crust": "#050a19",
    "surface0": "#172031", "surface1": "#252e3e", "surface2": "#343e4d",
    "overlay0": "#51688e", "overlay1": "#91a8bf", "overlay2": "#bcd3df",
    "text": "#e0f7fa", "subtext0": "#e1e9f5", "subtext1": "#91a8bf",
    "blue": "#f7c3c6", "sapphire": "#fff6d2", "peach": "#d7ebe9",
    "green": "#6488ea", "red": "#e95c4b", "mauve": "#85cec4",
    "pink": "#8cc7bf", "yellow": "#d5edeb", "maroon": "#ed7b6d",
  },
  "shades_of_jade": {
    "base": "#00110b", "mantle": "#00100a", "crust": "#000e09",
    "surface0": "#12231d", "surface1": "#20312b", "surface2": "#30413b",
    "overlay0": "#3e6650", "overlay1": "#8aa798", "overlay2": "#bcd2c8",
    "text": "#e6f6f0", "subtext0": "#fff7f2", "subtext1": "#8aa798",
    "blue": "#ff6600", "sapphire": "#80d4b5", "peach": "#d1ffb0",
    "green": "#00a86b", "red": "#ff3370", "mauve": "#8fc85c",
    "pink": "#8fc85c", "yellow": "#d1ffb0", "maroon": "#ff3370",
  },
  "space_monkey": {
    "base": "#1c0e00", "mantle": "#1a0d00", "crust": "#160b00",
    "surface0": "#2c1a07", "surface1": "#38240d", "surface2": "#472f13",
    "overlay0": "#948a8b", "overlay1": "#b99875", "overlay2": "#d2a266",
    "text": "#e7aa5a", "subtext0": "#f1e5e7", "subtext1": "#b99875",
    "blue": "#66a891", "sapphire": "#bd4924", "peach": "#fcd675",
    "green": "#df782d", "red": "#fd6883", "mauve": "#a8a9eb",
    "pink": "#bebffd", "yellow": "#f9cc6c", "maroon": "#ff8297",
  },
  "snow": {
    "base": "#ffffff", "mantle": "#ebebeb", "crust": "#cccccc",
    "surface0": "#ebebeb", "surface1": "#dddddd", "surface2": "#cccccc",
    "overlay0": "#919191", "overlay1": "#545454", "overlay2": "#2c2c2c",
    "text": "#0a0a0a", "subtext0": "#000000", "subtext1": "#545454",
    "blue": "#0a0a0a", "sapphire": "#0a0a0a", "peach": "#0a0a0a",
    "green": "#0a0a0a", "red": "#0a0a0a", "mauve": "#0a0a0a",
    "pink": "#0a0a0a", "yellow": "#0a0a0a", "maroon": "#0a0a0a",
  },
  "snow_black": {
    "base": "#000000", "mantle": "#000000", "crust": "#000000",
    "surface0": "#141414", "surface1": "#242424", "surface2": "#353535",
    "overlay0": "#1a1a1a", "overlay1": "#818181", "overlay2": "#c5c5c5",
    "text": "#fefefe", "subtext0": "#f5f5f5", "subtext1": "#818181",
    "blue": "#bdbdbd", "sapphire": "#bdbdbd", "peach": "#cfcfcf",
    "green": "#bdbdbd", "red": "#fefefe", "mauve": "#bdbdbd",
    "pink": "#bdbdbd", "yellow": "#cfcfcf", "maroon": "#f5f5f5",
  },
  "solarized_osaka": {
    "base": "#001c2b", "mantle": "#072a39", "crust": "#001622",
    "surface0": "#092432", "surface1": "#0f2937", "surface2": "#17303d",
    "overlay0": "#5f6f74", "overlay1": "#65757a", "overlay2": "#69797e",
    "text": "#6c7c81", "subtext0": "#e9e2d0", "subtext1": "#65757a",
    "blue": "#268bd2", "sapphire": "#2aa198", "peach": "#b38800",
    "green": "#809900", "red": "#d8322f", "mauve": "#d03682",
    "pink": "#d03682", "yellow": "#b38800", "maroon": "#d8322f",
  },
  "starry_night": {
    "base": "#000519", "mantle": "#000517", "crust": "#000414",
    "surface0": "#111628", "surface1": "#1d2333", "surface2": "#2c3240",
    "overlay0": "#4e5d70", "overlay1": "#89959d", "overlay2": "#b0bbba",
    "text": "#d1dad3", "subtext0": "#f6faf6", "subtext1": "#89959d",
    "blue": "#3873c8", "sapphire": "#008697", "peach": "#becf3d",
    "green": "#56ca9c", "red": "#a2b238", "mauve": "#3673ca",
    "pink": "#498df4", "yellow": "#a2b23d", "maroon": "#becf43",
  },
  "starsend": {
    "base": "#05090a", "mantle": "#050809", "crust": "#040708",
    "surface0": "#14191a", "surface1": "#202526", "surface2": "#2d3334",
    "overlay0": "#617877", "overlay1": "#8da09f", "overlay2": "#aabcba",
    "text": "#c3d2d0", "subtext0": "#f4faf8", "subtext1": "#8da09f",
    "blue": "#8299aa", "sapphire": "#7ba6a3", "peach": "#dcc294",
    "green": "#86a68f", "red": "#d2705c", "mauve": "#b58c99",
    "pink": "#cda6b2", "yellow": "#c9a878", "maroon": "#e88a75",
  },
  "sunset": {
    "base": "#070605", "mantle": "#060605", "crust": "#060504",
    "surface0": "#1b1a19", "surface1": "#2a2928", "surface2": "#3b3a3a",
    "overlay0": "#969596", "overlay1": "#c5c5c5", "overlay2": "#e5e4e5",
    "text": "#ffffff", "subtext0": "#d7d6d7", "subtext1": "#c5c5c5",
    "blue": "#d0b59b", "sapphire": "#fce7b0", "peach": "#ddd6d0",
    "green": "#f7ce6e", "red": "#dda660", "mauve": "#ebd2a4",
    "pink": "#fdfbf8", "yellow": "#b2a295", "maroon": "#efd5b4",
  },
  "sunset_drive": {
    "base": "#0f0f19", "mantle": "#0a0a12", "crust": "#0c0c14",
    "surface0": "#21212b", "surface1": "#2e2e39", "surface2": "#3e3e49",
    "overlay0": "#181824", "overlay1": "#787886", "overlay2": "#b8b8c8",
    "text": "#ededfe", "subtext0": "#f8f8ff", "subtext1": "#787886",
    "blue": "#33a1ff", "sapphire": "#3cffed", "peach": "#ffff80",
    "green": "#00f59b", "red": "#ff3366", "mauve": "#ff66f6",
    "pink": "#ff99ff", "yellow": "#ffea00", "maroon": "#ff9a8f",
  },
  "super_game_bro": {
    "base": "#214130", "mantle": "#416828", "crust": "#1a3426",
    "surface0": "#29492f", "surface1": "#2f4f2f", "surface2": "#37572e",
    "overlay0": "#416828", "overlay1": "#618528", "overlay2": "#769827",
    "text": "#88a827", "subtext0": "#88a827", "subtext1": "#618528",
    "blue": "#88a827", "sapphire": "#88a827", "peach": "#88a827",
    "green": "#88a827", "red": "#88a827", "mauve": "#88a827",
    "pink": "#88a827", "yellow": "#699020", "maroon": "#88a827",
  },
  "synthwave_84": {
    "base": "#240037", "mantle": "#262335", "crust": "#1d002c",
    "surface0": "#361447", "surface1": "#432453", "surface2": "#523661",
    "overlay0": "#614d85", "overlay1": "#a89dbc", "overlay2": "#d8d2e0",
    "text": "#ffffff", "subtext0": "#ffffff", "subtext1": "#a89dbc",
    "blue": "#0080ff", "sapphire": "#03edf9", "peach": "#ffff66",
    "green": "#8f00ff", "red": "#ff0040", "mauve": "#ff00ff",
    "pink": "#ff7edb", "yellow": "#f3e70f", "maroon": "#fe5442",
  },
  "temerald": {
    "base": "#121111", "mantle": "#222222", "crust": "#0e0e0e",
    "surface0": "#222422", "surface1": "#2e322f", "surface2": "#3c423e",
    "overlay0": "#6b6b6b", "overlay1": "#9eaca3", "overlay2": "#c0d8c8",
    "text": "#dcfce7", "subtext0": "#b4b4b4", "subtext1": "#9eaca3",
    "blue": "#93c5fd", "sapphire": "#86efab", "peach": "#dfb265",
    "green": "#4ade7f", "red": "#d35f5f", "mauve": "#a78bfa",
    "pink": "#c4b5fd", "yellow": "#d4953b", "maroon": "#df6969",
  },
  "terminus": {
    "base": "#0c1626", "mantle": "#0b1423", "crust": "#0a121e",
    "surface0": "#1c2431", "surface1": "#292f3a", "surface2": "#373c44",
    "overlay0": "#5e6e87", "overlay1": "#95989b", "overlay2": "#bab4a9",
    "text": "#d8cbb4", "subtext0": "#f2e8d5", "subtext1": "#95989b",
    "blue": "#6e93bb", "sapphire": "#7fa8ab", "peach": "#f0d4a0",
    "green": "#93b56f", "red": "#db684c", "mauve": "#ab7fa8",
    "pink": "#c9a3c4", "yellow": "#d9a862", "maroon": "#e07a5f",
  },
  "tokyo_night_oled": {
    "base": "#000000", "mantle": "#32344a", "crust": "#000000",
    "surface0": "#0e0e11", "surface1": "#18191e", "surface2": "#23252d",
    "overlay0": "#444b6a", "overlay1": "#71799b", "overlay2": "#9098bb",
    "text": "#a9b1d6", "subtext0": "#787c99", "subtext1": "#71799b",
    "blue": "#7aa2f7", "sapphire": "#449dab", "peach": "#ff9e64",
    "green": "#9ece6a", "red": "#f7768e", "mauve": "#ad8ee6",
    "pink": "#bb9af7", "yellow": "#e0af68", "maroon": "#ff7a93",
  },
  "tycho": {
    "base": "#1e2125", "mantle": "#1c1e22", "crust": "#181a1e",
    "surface0": "#2f3135", "surface1": "#3b3d41", "surface2": "#4a4b4f",
    "overlay0": "#897981", "overlay1": "#b7abb1", "overlay2": "#d6cdd1",
    "text": "#f0e9ec", "subtext0": "#c5aeb9", "subtext1": "#b7abb1",
    "blue": "#9b826b", "sapphire": "#706b82", "peach": "#dfbab2",
    "green": "#b4756b", "red": "#976870", "mauve": "#b48162",
    "pink": "#d5b8a7", "yellow": "#c17a6a", "maroon": "#c1a4a9",
  },
  "waffle_cat": {
    "base": "#292025", "mantle": "#261d22", "crust": "#211a1e",
    "surface0": "#3a3133", "surface1": "#473e3e", "surface2": "#564d4b",
    "overlay0": "#a58c82", "overlay1": "#cebba9", "overlay2": "#e8dac2",
    "text": "#fff4d8", "subtext0": "#fffaf0", "subtext1": "#cebba9",
    "blue": "#c87d2a", "sapphire": "#9eb8b2", "peach": "#e4c56d",
    "green": "#9fad68", "red": "#cf7358", "mauve": "#c98c97",
    "pink": "#ddb0b8", "yellow": "#c8964b", "maroon": "#e58a70",
  },
  "waveform_dark": {
    "base": "#0a0a0a", "mantle": "#1a0a0a", "crust": "#080808",
    "surface0": "#1e1515", "surface1": "#2c1e1e", "surface2": "#3d2828",
    "overlay0": "#4a2020", "overlay1": "#9b5656", "overlay2": "#d27b7b",
    "text": "#ff9999", "subtext0": "#ffcccc", "subtext1": "#9b5656",
    "blue": "#cc00ff", "sapphire": "#ff66cc", "peach": "#ffcc33",
    "green": "#ff6600", "red": "#ff3333", "mauve": "#ff00aa",
    "pink": "#ff33cc", "yellow": "#ffaa00", "maroon": "#ff6666",
  },
  "white_gold": {
    "base": "#dedbc8", "mantle": "#ccc9b8", "crust": "#b2afa0",
    "surface0": "#cdcaba", "surface1": "#c1beaf", "surface2": "#b2b0a2",
    "overlay0": "#9a9078", "overlay1": "#5a554b", "overlay2": "#302d2d",
    "text": "#0c0c14", "subtext0": "#665e4a", "subtext1": "#5a554b",
    "blue": "#005c32", "sapphire": "#3b3b3b", "peach": "#005c32",
    "green": "#725c0a", "red": "#4b0304", "mauve": "#762b2f",
    "pink": "#762b2f", "yellow": "#2e311a", "maroon": "#4b0304",
  },
  "windows_dark_mode": {
    "base": "#181818", "mantle": "#161616", "crust": "#131313",
    "surface0": "#262626", "surface1": "#313131", "surface2": "#3e3e3e",
    "overlay0": "#616161", "overlay1": "#919191", "overlay2": "#b1b1b1",
    "text": "#cccccc", "subtext0": "#ffffff", "subtext1": "#919191",
    "blue": "#0078d4", "sapphire": "#4daafc", "peach": "#bb8009",
    "green": "#2ea043", "red": "#f85149", "mauve": "#c586c0",
    "pink": "#c586c0", "yellow": "#bb8009", "maroon": "#f85149",
  },
  "winslow": {
    "base": "#13201b", "mantle": "#111d19", "crust": "#0f1a16",
    "surface0": "#232e27", "surface1": "#2e3830", "surface2": "#3c433a",
    "overlay0": "#616865", "overlay1": "#969487", "overlay2": "#b9b19e",
    "text": "#d6c9b1", "subtext0": "#e0d7c5", "subtext1": "#969487",
    "blue": "#9ba4bb", "sapphire": "#83a2a3", "peach": "#c3b798",
    "green": "#6f806d", "red": "#85795f", "mauve": "#857961",
    "pink": "#aa9d7e", "yellow": "#9d917a", "maroon": "#aa9e7b",
  },
  "van_gogh": {
    "base": "#0a192f", "mantle": "#09172b", "crust": "#081426",
    "surface0": "#1d2938", "surface1": "#2a353f", "surface2": "#3b4348",
    "overlay0": "#2c4668", "overlay1": "#858c83", "overlay2": "#c0bb95",
    "text": "#f2e2a4", "subtext0": "#fff3c4", "subtext1": "#858c83",
    "blue": "#4a78a8", "sapphire": "#9fd3c7", "peach": "#f6f1c1",
    "green": "#7fb3d5", "red": "#d9822b", "mauve": "#d9822b",
    "pink": "#ff9f1c", "yellow": "#f2e2a4", "maroon": "#ff9f1c",
  },
  "vault": {
    "base": "#191510", "mantle": "#17130f", "crust": "#14110d",
    "surface0": "#28231c", "surface1": "#332d25", "surface2": "#403930",
    "overlay0": "#867658", "overlay1": "#a9977c", "overlay2": "#c0ae94",
    "text": "#d3c0a8", "subtext0": "#f4e9d7", "subtext1": "#a9977c",
    "blue": "#79a5cc", "sapphire": "#63b8a6", "peach": "#e9c07c",
    "green": "#9cba64", "red": "#db6c4f", "mauve": "#cd8ba4",
    "pink": "#dda5b8", "yellow": "#d9ab5e", "maroon": "#e0755a",
  },
  "velvet_night": {
    "base": "#0a101f", "mantle": "#090f1d", "crust": "#080d19",
    "surface0": "#1e2331", "surface1": "#2c313e", "surface2": "#3d424e",
    "overlay0": "#6b72a8", "overlay1": "#aeb1cf", "overlay2": "#dadce9",
    "text": "#ffffff", "subtext0": "#f5ecdf", "subtext1": "#aeb1cf",
    "blue": "#9099a5", "sapphire": "#c24f40", "peach": "#f0d17c",
    "green": "#5c637a", "red": "#811139", "mauve": "#e2687c",
    "pink": "#e88595", "yellow": "#e5af1b", "maroon": "#e21d63",
  },
  "venice_from_above": {
    "base": "#f5f2e9", "mantle": "#e1dfd6", "crust": "#c4c2ba",
    "surface0": "#e7e2d9", "surface1": "#ddd6cd", "surface2": "#d1c8c0",
    "overlay0": "#85837d", "overlay1": "#6a5a55", "overlay2": "#58403a",
    "text": "#492924", "subtext0": "#6e4740", "subtext1": "#6a5a55",
    "blue": "#72684b", "sapphire": "#726947", "peach": "#938a5e",
    "green": "#6f6644", "red": "#706548", "mauve": "#796e51",
    "pink": "#9e926c", "yellow": "#6f6645", "maroon": "#948962",
  },
  "vesper": {
    "base": "#101010", "mantle": "#0f0f0f", "crust": "#0d0d0d",
    "surface0": "#232323", "surface1": "#313131", "surface2": "#424242",
    "overlay0": "#7e7e7e", "overlay1": "#b8b8b8", "overlay2": "#dfdfdf",
    "text": "#ffffff", "subtext0": "#a0a0a0", "subtext1": "#b8b8b8",
    "blue": "#aca1cf", "sapphire": "#ea83a5", "peach": "#ffc799",
    "green": "#90b99f", "red": "#f5a191", "mauve": "#e29eca",
    "pink": "#ecaad6", "yellow": "#e6b99d", "maroon": "#ff8080",
  },
  "vhs_80": {
    "base": "#121212", "mantle": "#333333", "crust": "#0e0e0e",
    "surface0": "#222222", "surface1": "#2d2d2d", "surface2": "#3b3b3b",
    "overlay0": "#8a8a8d", "overlay1": "#ababad", "overlay2": "#c2c2c2",
    "text": "#d4d4d4", "subtext0": "#bebebe", "subtext1": "#ababad",
    "blue": "#8b7f2e", "sapphire": "#2f8383", "peach": "#e07924",
    "green": "#277d46", "red": "#862020", "mauve": "#932a37",
    "pink": "#c73838", "yellow": "#a85511", "maroon": "#c73838",
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
  "vulkanite": {
    "base": "#0f1416", "mantle": "#0e1214", "crust": "#0c1012",
    "surface0": "#1f2527", "surface1": "#2c3134", "surface2": "#3a4042",
    "overlay0": "#8e969a", "overlay1": "#b1babe", "overlay2": "#c8d1d5",
    "text": "#dce5e9", "subtext0": "#dce5e9", "subtext1": "#b1babe",
    "blue": "#76c7e3", "sapphire": "#37868b", "peach": "#e0af68",
    "green": "#8be086", "red": "#e05f64", "mauve": "#9083b9",
    "pink": "#9083b9", "yellow": "#e0af68", "maroon": "#e03f32",
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
  # Omarchy community themes (https://omarchy.org/themes)
  aetheria)                       PRESET="aetheria" ;;
  amberbyte)                      PRESET="amberbyte" ;;
  arc_blueberry)                  PRESET="arc_blueberry" ;;
  archwave)                       PRESET="archwave" ;;
  ash)                            PRESET="ash" ;;
  artzen)                         PRESET="artzen" ;;
  aura)                           PRESET="aura" ;;
  all_hallows_eve)                PRESET="all_hallows_eve" ;;
  atelier)                        PRESET="atelier" ;;
  ayaka)                          PRESET="ayaka" ;;
  azure_glow)                     PRESET="azure_glow" ;;
  batman)                         PRESET="batman" ;;
  batou)                          PRESET="batou" ;;
  bauhaus)                        PRESET="bauhaus" ;;
  biscuit_de_mar_dark)            PRESET="biscuit_de_mar_dark" ;;
  black_arch)                     PRESET="black_arch" ;;
  black_gold)                     PRESET="black_gold" ;;
  black_sand)                     PRESET="black_sand" ;;
  bluedotrb)                      PRESET="bluedotrb" ;;
  blue_ridge_dark)                PRESET="blue_ridge_dark" ;;
  castle_on_a_lake)               PRESET="castle_on_a_lake" ;;
  catppuccin_mocha_dark)          PRESET="catppuccin_mocha_dark" ;;
  cincinnati)                     PRESET="cincinnati" ;;
  citrus_cynapse)                 PRESET="citrus_cynapse" ;;
  city_783)                       PRESET="city_783" ;;
  cobalt2)                        PRESET="cobalt2" ;;
  coffee)                         PRESET="coffee" ;;
  coffee_latte)                   PRESET="coffee_latte" ;;
  commit)                         PRESET="commit" ;;
  cpunk)                          PRESET="cpunk" ;;
  crimson_gold)                   PRESET="crimson_gold" ;;
  darcula)                        PRESET="darcula" ;;
  demon)                          PRESET="demon" ;;
  dotrb)                          PRESET="dotrb" ;;
  dos_moos)                       PRESET="dos_moos" ;;
  drac)                           PRESET="drac" ;;
  eldritch)                       PRESET="eldritch" ;;
  event_horizon)                  PRESET="event_horizon" ;;
  evergarden)                     PRESET="evergarden" ;;
  felix)                          PRESET="felix" ;;
  fireside)                       PRESET="fireside" ;;
  flat_dracula)                   PRESET="flat_dracula" ;;
  flexoki_dark)                   PRESET="flexoki_dark" ;;
  forest_green)                   PRESET="forest_green" ;;
  frost)                          PRESET="frost" ;;
  fuchsblau)                      PRESET="fuchsblau" ;;
  futurism)                       PRESET="futurism" ;;
  futurist)                       PRESET="futurist" ;;
  gand)                           PRESET="gand" ;;
  ghost_pastel)                   PRESET="ghost_pastel" ;;
  gold_rush)                      PRESET="gold_rush" ;;
  golden_brown)                   PRESET="golden_brown" ;;
  the_greek)                      PRESET="the_greek" ;;
  greek_noir)                     PRESET="greek_noir" ;;
  green_garden)                   PRESET="green_garden" ;;
  gruvbox_material)               PRESET="gruvbox_material" ;;
  harbor)                         PRESET="harbor" ;;
  harbor_dark)                    PRESET="harbor_dark" ;;
  hermarchy)                      PRESET="hermarchy" ;;
  hinterlands)                    PRESET="hinterlands" ;;
  infernium)                      PRESET="infernium" ;;
  inky_pinky)                     PRESET="inky_pinky" ;;
  japan_night)                    PRESET="japan_night" ;;
  lamplight)                      PRESET="lamplight" ;;
  lawson_night)                   PRESET="lawson_night" ;;
  map_quest)                      PRESET="map_quest" ;;
  mars)                           PRESET="mars" ;;
  matrix)                         PRESET="matrix" ;;
  mechanoonna)                    PRESET="mechanoonna" ;;
  midnight)                       PRESET="midnight" ;;
  milky_matcha)                   PRESET="milky_matcha" ;;
  mini_jcw)                       PRESET="mini_jcw" ;;
  moodpeak)                       PRESET="moodpeak" ;;
  nagai_poolside)                 PRESET="nagai_poolside" ;;
  naysayer)                       PRESET="naysayer" ;;
  neo_sploosh)                    PRESET="neo_sploosh" ;;
  neon_dusk)                      PRESET="neon_dusk" ;;
  neovoid)                        PRESET="neovoid" ;;
  neptune_blue)                   PRESET="neptune_blue" ;;
  nes)                            PRESET="nes" ;;
  noir)                           PRESET="noir" ;;
  oligarchy)                      PRESET="oligarchy" ;;
  nujabes)                        PRESET="nujabes" ;;
  omacarchy)                      PRESET="omacarchy" ;;
  omaled)                         PRESET="omaled" ;;
  one_dark)                       PRESET="one_dark" ;;
  one_dark_pro)                   PRESET="one_dark_pro" ;;
  oxo_carbon)                     PRESET="oxo_carbon" ;;
  pagan)                          PRESET="pagan" ;;
  pandora)                        PRESET="pandora" ;;
  periphery)                      PRESET="periphery" ;;
  pina)                           PRESET="pina" ;;
  pink_blood)                     PRESET="pink_blood" ;;
  pulsar)                         PRESET="pulsar" ;;
  purple_moon)                    PRESET="purple_moon" ;;
  purplewave)                     PRESET="purplewave" ;;
  quattrocento_light)             PRESET="quattrocento_light" ;;
  rainy_night)                    PRESET="rainy_night" ;;
  red_monarch)                    PRESET="red_monarch" ;;
  red_pill)                       PRESET="red_pill" ;;
  retropc)                        PRESET="retropc" ;;
  ristretto_light)                PRESET="ristretto_light" ;;
  robzee84)                       PRESET="robzee84" ;;
  rose_pine_dark)                 PRESET="rose_pine_dark" ;;
  rose_pine_moon)                 PRESET="rose_pine_moon" ;;
  rose_of_dune)                   PRESET="rose_of_dune" ;;
  ryu)                            PRESET="ryu" ;;
  sakura)                         PRESET="sakura" ;;
  sakura_mochi)                   PRESET="sakura_mochi" ;;
  saga)                           PRESET="saga" ;;
  sapphire)                       PRESET="sapphire" ;;
  shades_of_jade)                 PRESET="shades_of_jade" ;;
  space_monkey)                   PRESET="space_monkey" ;;
  snow)                           PRESET="snow" ;;
  snow_black)                     PRESET="snow_black" ;;
  solarized_osaka)                PRESET="solarized_osaka" ;;
  starry_night)                   PRESET="starry_night" ;;
  starsend)                       PRESET="starsend" ;;
  sunset)                         PRESET="sunset" ;;
  sunset_drive)                   PRESET="sunset_drive" ;;
  super_game_bro)                 PRESET="super_game_bro" ;;
  synthwave_84)                   PRESET="synthwave_84" ;;
  temerald)                       PRESET="temerald" ;;
  terminus)                       PRESET="terminus" ;;
  tokyo_night_oled)               PRESET="tokyo_night_oled" ;;
  tycho)                          PRESET="tycho" ;;
  waffle_cat)                     PRESET="waffle_cat" ;;
  waveform_dark)                  PRESET="waveform_dark" ;;
  white_gold)                     PRESET="white_gold" ;;
  windows_dark_mode)              PRESET="windows_dark_mode" ;;
  winslow)                        PRESET="winslow" ;;
  van_gogh)                       PRESET="van_gogh" ;;
  vault)                          PRESET="vault" ;;
  velvet_night)                   PRESET="velvet_night" ;;
  venice_from_above)              PRESET="venice_from_above" ;;
  vesper)                         PRESET="vesper" ;;
  vhs_80)                         PRESET="vhs_80" ;;
  void)                           PRESET="void" ;;
  vulkanite)                      PRESET="vulkanite" ;;
  lumon)                          PRESET="lumon" ;;
  akane)                          PRESET="akane" ;;
  aamis)                          PRESET="aamis" ;;
  copper_night)                   PRESET="copper_night" ;;
  ibm)                            PRESET="ibm" ;;
  retro_fallout)                  PRESET="retro_fallout" ;;
  solitude)                       PRESET="solitude" ;;
  blackturq)                      PRESET="blackturq" ;;
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

# QuickShell only: write the chosen light/dark mode for the bar to read.
# Matugen stays dark/light per PREFER but qs-theme only affects QuickShell's
# pill coloring (the rest of the system follows the matugen run above).
printf '%s\n' "$QUICK" > "$QUICK_THEME_FILE"

# Remember the last applied wallpaper so the picker can preselect it.
printf '%s\n' "$IMG" > "$CACHE/current.txt"
printf '%s\n%s\n' "$SCHEME" "$HEX" > "$CACHE/scheme.txt.tmp"
mv -f "$CACHE/scheme.txt.tmp" "$CACHE/scheme.txt"

exit 0