// Mango close, structured like the perlin shader:
// sample texture, single reveal multiply, nothing else.

// mango animation_curve_close = cubic-bezier(0.08, 0.92, 0.0, 1.0)
float mango_bezier_close(float x) {
    vec4 c = vec4(0.08, 0.92, 0.0, 1.0);
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

vec4 close_color(vec3 coords_geo, vec3 size_geo) {
    float pr = 1.0 - niri_clamped_progress;
    float e = mango_bezier_close(1.0 - pr);

    // mango close is pure fade: no zoom, window stays full-size
    vec2 uv = coords_geo.xy;
    vec3 tc = niri_geo_to_tex * vec3(uv, 1.0);
    vec4 win = texture2D(niri_tex, tc.st);

    // mango fade out: fadeout_begin_opacity 0.8 -> 0.0
    float reveal = 0.8 * (1.0 - e);

    return win * reveal;
}
