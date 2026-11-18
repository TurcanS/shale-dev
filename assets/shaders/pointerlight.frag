#version 440
// Shale's pointer light (components/PointerLight.qml): a soft pool of light at `spot` inside a rounded
// rectangle, added to what is under it. Rebuild the .qsb after a change:
//   /usr/lib/qt6/bin/qsb --qt6 -o pointerlight.frag.qsb pointerlight.frag
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 box;
    vec2 spot;
    float corner;
    float spread;
    vec4 tint;
};

float roundedBox(vec2 p, vec2 half_, float r) {
    vec2 q = abs(p) - half_ + r;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void main() {
    vec2 p = qt_TexCoord0 * box;
    float inside = clamp(0.5 - roundedBox(p - box * 0.5, box * 0.5, corner), 0.0, 1.0);
    float fall = 1.0 - smoothstep(0.0, spread, distance(p, spot));
    // Zero alpha: the scene graph adds the colour instead of covering, so the light brightens what is under it.
    fragColor = vec4(tint.rgb * (inside * fall * fall * qt_Opacity), 0.0);
}
