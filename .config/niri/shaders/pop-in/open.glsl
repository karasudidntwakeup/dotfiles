vec4 open_color(vec3 coords_geo, vec3 size_geo) {
    float p = niri_clamped_progress;
    vec2 uv = coords_geo.xy;
    vec2 center = vec2(0.5, 0.5);

    // layer 1: dramatic zoom 0.7 -> 1.0 with slight overshoot
    float t = p;
    float base = mix(0.7, 1.0, t);
    float overshoot = 1.0 + 0.03 * sin(t * 3.14159);
    float scale = base * overshoot;
    vec2 scaled_uv = (uv - center) / scale + center;

    if (scaled_uv.x < 0.0 || scaled_uv.x > 1.0 || scaled_uv.y < 0.0 || scaled_uv.y > 1.0)
        return vec4(0.0);

    vec3 tc = niri_geo_to_tex * vec3(scaled_uv, 1.0);
    vec4 win = texture2D(niri_tex, tc.st);

    // layer 2: fade in, no brightness (avoids white clipping)
    float alpha = smoothstep(0.0, 0.7, t);

    return vec4(win.rgb * alpha, win.a * alpha);
}
