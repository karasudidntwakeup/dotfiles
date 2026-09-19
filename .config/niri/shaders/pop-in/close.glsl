vec4 close_color(vec3 coords_geo, vec3 size_geo) {
    float p = 1.0 - niri_clamped_progress;
    vec2 uv = coords_geo.xy;
    vec2 center = vec2(0.5, 0.5);

    // mirror of open: dramatic zoom 1.0 -> 0.7 with slight overshoot
    float t = p;
    float base = mix(0.7, 1.0, t);
    float overshoot = 1.0 + 0.03 * sin(t * 3.14159);
    float scale = base * overshoot;
    vec2 scaled_uv = (uv - center) / scale + center;

    vec3 tc = niri_geo_to_tex * vec3(scaled_uv, 1.0);
    vec4 win = texture2D(niri_tex, tc.st);

    // fade out, no brightness (avoids white clipping)
    float alpha = smoothstep(0.0, 0.7, t);

    return vec4(win.rgb * alpha, win.a * alpha);
}
