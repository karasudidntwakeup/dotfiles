/*
 * Quickshell Colors
 * Generated with Matugen
 */

/* Scheme colors (current mode) */

<* for name, value in colors *>
var {{name}} = "{{value.default.hex}}"
<* endfor *>

/* Light scheme variants */

<* for name, value in colors *>
var {{name}}_light = "{{value.light.hex}}"
<* endfor *>

/* Dark scheme variants */

<* for name, value in colors *>
var {{name}}_dark = "{{value.dark.hex}}"
<* endfor *>

/* Tonal palettes (tones 0-100) */

<* for pname, pal in palettes *>
<* for tone, tval in pal *>
var palette_{{pname}}_{{tone}} = "{{tval.hex}}"
<* endfor *>
<* endfor *>
