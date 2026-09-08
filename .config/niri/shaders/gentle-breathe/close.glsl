// gentle-breathe close: soft fade-out with subtle scale-down toward center
// Mirror of open — feels like a slow exhale of disappearance

vec4 close_color(vec3 coords_geo, vec3 size_geo) {
    float p = 1.0 - niri_clamped_progress;
    vec2 uv = coords_geo.xy;

    vec2 center = vec2(0.5, 0.5);

    // Subtle scale-down: 1.0 → 0.96
    float scale = mix(1.0, 0.96, p);

    vec2 scaled_uv = (uv - center) / scale + center;

    vec3 tc = niri_geo_to_tex * vec3(scaled_uv, 1.0);
    vec4 win = texture2D(niri_tex, tc.st);

    // Soft fade-out: ease-out, stays visible longer then gently fades
    float alpha = smoothstep(1.0, 0.15, p);

    // Warmth fades out as the window disappears
    vec3 warm = vec3(1.0, 0.97, 0.94);
    vec3 color = mix(win.rgb * warm, win.rgb, p * 0.08);

    return vec4(color, win.a * alpha);
}
