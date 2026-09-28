#language slang 2026
// Aperture-grille CRT: curvature + scanlines + RGB phosphor mask + vignette.
// Static (no animation) — cheap enough for daily use.
import kitty_custom_shader_types;

static const float WARP = 0.25f;
static const float SCAN = 0.55f;
static const float4 TINT = float4(0, 0.8, 0.6, 0);
static const float GRILLE = 0.28f;   // RGB mask strength, 0 = off
static const float VIGNETTE = 0.35f; // corner darkening, 0 = off

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

    // RGB aperture grille: every 3rd pixel column favors one channel
    if (GRILLE > 0.0f) {
        float px = t.pos.x * float(d.viewport_size_pixels.x) * t.viewport.z;
        float m = fmod(px, 3.0f);
        float3 mask = float3(
            m < 1.0f ? 1.0f : 1.0f - GRILLE,
            (m >= 1.0f && m < 2.0f) ? 1.0f : 1.0f - GRILLE,
            m >= 2.0f ? 1.0f : 1.0f - GRILLE);
        col *= mask;
    }

    if (VIGNETTE > 0.0f) {
        float2 vc = t.pos - 0.5f;
        float vig = 1.0f - VIGNETTE * dot(vc, vc) * 2.0f;
        col *= clamp(vig, 0.0f, 1.0f);
    }

    return float4(col, 1);
}
