#language slang 2026
// Glow pulse: breathes brightness of bright pixels. Chain BEFORE bloom:
// `shaders glow-pulse bloom`. Animated — pipeline must set animation_start/stop.
import kitty_custom_shader_types;

static const float THRESH = 0.3f;      // luminance where pulse applies
static const float DEPTH = 0.18f;      // pulse depth, 0 = off
static const float SPEED = 2.2f;       // radians per second

public float4
fragment_main(float4 color, KittyTextures t, KittyCustomShaderData d) {
    float3 col = color.rgb;
    float l = 0.299f * col.r + 0.587f * col.g + 0.114f * col.b;
    float k = smoothstep(THRESH, 1.0f, l);
    float p = 1.0f + DEPTH * sin(d.timestamp * SPEED);
    col *= lerp(1.0f, p, k);
    return float4(col, color.a);
}
