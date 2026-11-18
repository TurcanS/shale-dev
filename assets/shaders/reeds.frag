#version 440
// Shale's case glass (components/Frost.qml): reeded glass. The wallpaper, blurred, shows through vertical reeds
// 16 px apart under the case colour; each reed is lighter over its crown and carries a thin glint, and the reeds
// near the pointer catch more light, as reeded glass does under a lamp. A fine grain gives the etched finish; the
// 1 px edge is a chamfer catching light at the top, with a dark line just inside it at the bottom. One pass per
// case, clipped to its rounded corners. Rebuild the .qsb after a change:
//   /usr/lib/qt6/bin/qsb --qt6 -o reeds.frag.qsb reeds.frag
// The running shell keeps a shader by its file name across reloads: rename the file to see a change without a restart.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    // The case in pixels, and where it lies on the wallpaper as a fraction of the screen (x, y, width, height).
    vec2 box;
    vec4 area;
    float corner;
    // The case colour and how much of the wallpaper it covers.
    vec4 tint;
    float cover;
    // How colourful the wallpaper shows, and the brightest it may show (relative luminance), so text keeps its
    // contrast on a bright picture.
    float vibrance;
    float ceiling;
    // The pointer in case pixels and how present it is (0 away, 1 over the case).
    vec2 pointer;
    float glow;
    // Per surface, 0 to 1: how strong the reeds are and how much they catch the pointer's light.
    float reeds;
    float glint;
};
layout(binding = 1) uniform sampler2D frosted;

float roundedBox(vec2 p, vec2 half_, float r) {
    vec2 q = abs(p) - half_ + r;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}
vec2 uvAt(vec2 px) { return area.xy + px / box * area.zw; }
float luma(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }
vec3 vivid(vec3 c, float amount) { return max(mix(vec3(luma(c)), c, amount), 0.0); }
vec3 capped(vec3 c, float top) { return c * min(1.0, top / max(luma(c), 0.0001)); }
float grain(vec2 p) {
    p = fract(p * vec2(443.897, 441.423));
    p += dot(p, p.yx + 19.19);
    return fract((p.x + p.y) * p.x) - 0.5;
}

void main() {
    vec2 p = qt_TexCoord0 * box;
    float depth = -roundedBox(p - box * 0.5, box * 0.5, corner);
    float inside = clamp(0.5 + depth, 0.0, 1.0);

    // Across one reed, -1 at its left side to 1 at its right; each reed shifts what it shows a little.
    float s = fract(p.x / 16.0) * 2.0 - 1.0;
    vec3 body = texture(frosted, uvAt(vec2(p.x - s * 16.0 * 0.8 * reeds, p.y))).rgb;
    vec3 color = mix(capped(vivid(body, vibrance), ceiling), tint.rgb, cover);
    color *= 1.0 - 0.05 * qt_TexCoord0.y;

    // The reed: lighter over its crown, a soft crease where two meet, and a glint left of the crown.
    float crown = sqrt(max(0.0, 1.0 - s * s));
    color *= 1.0 + reeds * (0.055 * crown - 0.035 - 0.035 * smoothstep(0.8, 1.0, abs(s)));
    float near = glow * exp(-length(p - pointer) / 170.0);
    float streak = exp(-pow((s + 0.38) / 0.16, 2.0));
    color += vec3(1.0) * streak * reeds * (0.012 + 0.08 * glint * near);

    color += grain(floor(p)) * 0.018;

    float hairline = clamp(1.0 - abs(depth - 0.75) / 0.75, 0.0, 1.0);
    float inner = clamp(1.0 - abs(depth - 1.9) / 0.6, 0.0, 1.0);
    color = mix(color, vec3(1.0), hairline * (0.045 + 0.13 * (1.0 - smoothstep(0.0, 0.55, qt_TexCoord0.y))));
    color = mix(color, vec3(0.0), inner * 0.22 * smoothstep(0.5, 1.0, qt_TexCoord0.y));
    fragColor = vec4(color, 1.0) * (inside * qt_Opacity);
}
