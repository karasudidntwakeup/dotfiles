#language slang 2026
// Neon pop: saturates and lifts bright pixels so bloom has something to bite.
// Chain BEFORE bloom: `shaders neon-pop bloom`. Works standalone too.
import kitty_custom_shader_types;

static const float THRESH = 0.45f; // luminance where pop kicks in
static const float POP = 1.20f;    // brightness multiplier on brights
static const float SAT = 0.4f;     // extra saturation on brights

public float4
fragment_main(float4 color, KittyTextures t, KittyCustomShaderData d) {
    float3 col = color.rgb;
    float l = 0.299f * col.r + 0.587f * col.g + 0.114f * col.b;
    float k = smoothstep(THRESH, 1.0f, l);
    float3 sat = lerp(float3(l, l, l), col, 1.0f + SAT);
    col = lerp(col, sat * POP, k);
    return float4(col, color.a);
}
