#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;       // item size in px
    vec2 offset;     // where world (0,0) sits on screen, px
    float zoom;
    float kind;      // 0 none, 1 dots, 2 lines, 3 cross
    vec4 color;      // pattern colour (straight alpha)
};

void main() {
    if (kind < 0.5) { fragColor = vec4(0.0); return; }
    vec2 p = qt_TexCoord0 * size;
    float gap = 24.0 * zoom;
    for (int i = 0; i < 6; ++i) { if (gap < 14.0) gap *= 2.0; }       // thin out the grid instead of crowding it
    vec2 g = (p - offset) / gap;
    vec2 f = fract(g + 0.5) - 0.5;
    vec2 d = abs(f) * gap;                                              // px to the nearest grid line, per axis
    float a = 0.0;
    if (kind < 1.5) {
        float r = clamp(zoom * 1.5, 0.9, 1.7);
        a = 1.0 - smoothstep(r - 0.5, r + 0.5, length(d));
    } else if (kind < 2.5) {
        a = 1.0 - smoothstep(0.35, 1.15, min(d.x, d.y));
        a *= 0.55;
    } else {
        float arm = clamp(zoom * 5.0, 3.0, 6.0);
        float h = (1.0 - smoothstep(0.35, 1.15, d.y)) * (1.0 - smoothstep(arm - 1.0, arm, d.x));
        float v = (1.0 - smoothstep(0.35, 1.15, d.x)) * (1.0 - smoothstep(arm - 1.0, arm, d.y));
        a = max(h, v);
    }
    float al = a * color.a * qt_Opacity;
    fragColor = vec4(color.rgb * al, al);
}
