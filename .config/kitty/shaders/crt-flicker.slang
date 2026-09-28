#language slang 2026
// Animated CRT: curvature + scanlines + tint + flicker + rolling band + vignette.
// Tunables below can be overridden from a .pipeline with `var` lines.
import kitty_custom_shader_types;

static const float WARP = 0.25f;
static const float SCAN = 0.50f;
static const float4 TINT = float4(0, 0.8, 0.6, 0);
static const float FLICKER = 0.03f;        // 0 = off, ~0.05 = noticeable
static const float ROLL_INTENSITY = 0.06f; // brightness of rolling band, 0 = off
static const float ROLL_SPEED = 0.12f;     // bands per second
static const float VIGNETTE = 0.35f;       // 0 = off, corner darkening

public float4
fragment_main(float4 color, KittyTextures t, KittyCustomShaderData d) {
    float2 uv = t.pos;
    float2 dc = abs(0.5f - uv);
    dc *= dc;
    uv.x -= 0.5f;
    uv.x *= 1.0f + (dc.y * (0.3f * WARP));
    uv.x += 0.5f;
    uv.y -= 0.5f;
    uv.y *= 1.0f + (dc.x * (0.4f * WARP));
    uv.y += 0.5f;

    float fragCoordY = t.pos.y * float(d.viewport_size_pixels.y) * t.viewport.w;
    float apply = abs(sin(fragCoordY) * 0.25f * SCAN);

    float3 col = t.backbuffer.Sample(uv).rgb;
    col = lerp(col, col * TINT.rgb, TINT.a);
    col = lerp(col, float3(0.0f), apply);

    // subtle brightness flicker
    float flick = 1.0f - FLICKER * (0.5f + 0.5f * sin(d.timestamp * 60.0f));
    col *= flick;

    // rolling interference band (bottom -> top)
    if (ROLL_INTENSITY > 0.0f) {
        float band_pos = fract(d.timestamp * ROLL_SPEED);
        float dist = t.pos.y - band_pos;
        float band = exp(-dist * dist * 220.0f) * ROLL_INTENSITY;
        col += band;
    }

    // vignette
    if (VIGNETTE > 0.0f) {
        float2 vc = t.pos - 0.5f;
        float vig = 1.0f - VIGNETTE * dot(vc, vc) * 2.0f;
        col *= clamp(vig, 0.0f, 1.0f);
    }

    return float4(col, 1);
}
