#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;       // item size in world units
    float radius;
    float aa;        // one screen pixel, in world units
    float aspect;    // source width / height
    float fit;       // 1 = cover, 0 = contain
    float dim;       // 0..1 darken (paused video, etc.)
};
layout(binding = 1) uniform sampler2D source;

void main() {
    vec2 uv = qt_TexCoord0;
    float ta = size.x / size.y;
    vec2 st = uv;
    if (fit > 0.5) {
        if (aspect > ta) st.x = (uv.x - 0.5) * (ta / aspect) + 0.5;
        else st.y = (uv.y - 0.5) * (aspect / ta) + 0.5;
    }
    vec2 p = (uv - 0.5) * size;
    vec2 b = size * 0.5 - vec2(radius);
    vec2 q = abs(p) - b;
    float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
    float a = 1.0 - smoothstep(-aa, 0.0, d);
    vec4 c = texture(source, st);
    c.rgb *= (1.0 - dim);
    fragColor = c * a * qt_Opacity;
}
