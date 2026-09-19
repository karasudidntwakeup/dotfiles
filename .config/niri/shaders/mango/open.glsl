// Mango open, structured like the perlin shader:
// sample texture, single reveal multiply, nothing else.

// mango animation_curve_open = cubic-bezier(0.46, 1.0, 0.29, 1.1)
float mango_bezier_open(float x) {
    vec4 c = vec4(0.46, 1.0, 0.29, 1.1);
    float t = x;
    for (int i = 0; i < 8; i++) {
        float mt = 1.0 - t;
        float bx = 3.0 * mt * mt * t * c.x + 3.0 * mt * t * t * c.z + t * t * t;
        float dx = 3.0 * mt * mt * c.x + 6.0 * mt * t * (c.z - c.x) + 3.0 * t * t * (1.0 - c.z);
        if (abs(dx) < 1e-6) break;
        t = clamp(t - (bx - x) / dx, 0.0, 1.0);
    }
    float mt = 1.0 - t;
    return 3.0 * mt * mt * t * c.y + 3.0 * mt * t * t * c.w + t * t * t;
}

vec4 open_color(vec3 coords_geo, vec3 size_geo) {
    float pr = niri_clamped_progress;
    float e = mango_bezier_open(pr);

    // mango zoom: starts at 0.3, must end at 1.0 for a seamless handoff
    float scale = mix(0.3, 1.0, e);
    vec2 uv = (coords_geo.xy - vec2(0.5)) / scale + vec2(0.5);
    vec3 tc = niri_geo_to_tex * vec3(uv, 1.0);
    vec4 win = texture2D(niri_tex, tc.st);

    // mango fade in: fadein_begin_opacity 0.6 -> 1.0
    float reveal = mix(0.6, 1.0, e);

    // outside the zoomed content there is no window yet
    if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0)
        return vec4(0.0);

    return win * reveal;
}
