// gentle-breathe open: soft fade-in with subtle scale-up from center
// Comfortable to human eyes — no harsh motion, just a slow exhale of visibility

vec4 open_color(vec3 coords_geo, vec3 size_geo) {
    float p = niri_clamped_progress;
    vec2 uv = coords_geo.xy;

    // Center of the window in normalized coords
    vec2 center = vec2(0.5, 0.5);

    // Very subtle scale: 0.96 → 1.0 over the transition
    // Small enough to feel like a gentle breath, not a zoom
    float scale = mix(0.96, 1.0, p);

    // Apply scale relative to center
    vec2 scaled_uv = (uv - center) / scale + center;

    // Map to texture coords
    vec3 tc = niri_geo_to_tex * vec3(scaled_uv, 1.0);
    vec4 win = texture2D(niri_tex, tc.st);

    // Soft fade-in: ease-out via smoothstep
    // Stays dark longer at the start, then gently reveals
    float alpha = smoothstep(0.0, 0.85, p);

    // Slight warmth boost at the tail end — very subtle
    vec3 warm = vec3(1.0, 0.97, 0.94);
    vec3 color = mix(win.rgb, win.rgb * warm, p * 0.08);

    return vec4(color, win.a * alpha);
}
