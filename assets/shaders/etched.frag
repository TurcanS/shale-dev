#version 440
// Shale's case glass (components/Frost.qml): etched glass. The wallpaper, blurred, shows through under the case
// colour; a fine grain gives the etched finish and keeps the blur from banding, and a soft light gathers where the
// pointer is. The 1 px edge is a chamfer catching light at the top, with a dark line just inside it at the bottom.
// One pass per case, clipped to its rounded corners. Rebuild the .qsb after a change:
//   /usr/lib/qt6/bin/qsb --qt6 -o etched.frag.qsb etched.frag
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
    // The pointer in case pixels, how present it is (0 away, 1 over the case), and how strong its light is here.
    vec2 pointer;
    float glow;
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

    vec3 body = texture(frosted, uvAt(p)).rgb;
    vec3 color = mix(capped(vivid(body, vibrance), ceiling), tint.rgb, cover);
    color *= 1.0 - 0.05 * qt_TexCoord0.y;
    // A soft light under the pointer, wide and faint, as if a lamp were near the glass.
    float near = glow * exp(-pow(length(p - pointer) / 220.0, 2.0));
    color += vec3(1.0) * near * 0.035 * glint;
    color += grain(floor(p)) * 0.018;

    float hairline = clamp(1.0 - abs(depth - 0.75) / 0.75, 0.0, 1.0);
    float inner = clamp(1.0 - abs(depth - 1.9) / 0.6, 0.0, 1.0);
    color = mix(color, vec3(1.0), hairline * (0.045 + 0.13 * (1.0 - smoothstep(0.0, 0.55, qt_TexCoord0.y))));
    color = mix(color, vec3(0.0), inner * 0.22 * smoothstep(0.5, 1.0, qt_TexCoord0.y));
    fragColor = vec4(color, 1.0) * (inside * qt_Opacity);
}
