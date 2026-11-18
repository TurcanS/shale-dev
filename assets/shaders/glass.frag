#version 440
// Shale's case glass (components/Frost.qml). Under the case colour, the wallpaper shows through a quiet fluted
// body; the rim is a bevel that bends in what lies just past the edge, split a little like cut glass, and lit by
// the wallpaper's own colour beyond it. Where the pointer is, the edge wakes up and a sheen in the accent colour
// slides across the glass. One pass per case, clipped to its rounded corners. Rebuild the .qsb after a change:
//   /usr/lib/qt6/bin/qsb --qt6 -o glass.frag.qsb glass.frag
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    // The case in pixels, and where it lies on the wallpaper as a fraction of the screen (x, y, width, height).
    vec2 box;
    vec4 area;
    float corner;
    // The case colour and how much of the wallpaper it covers; the accent for the sheen.
    vec4 tint;
    float cover;
    vec4 accent;
    // How colourful the wallpaper shows, and the brightest it may show (relative luminance), so text keeps its
    // contrast on a bright picture.
    float vibrance;
    float ceiling;
    // The pointer in case pixels and how present it is (0 away, 1 over the case).
    vec2 pointer;
    float glow;
    // Per surface: the bevel's width in pixels, and how strong the edge light, the sheen and the reeds are (0 to 1).
    float rim;
    float edgeGlow;
    float sheen;
    float reeds;
};
layout(binding = 1) uniform sampler2D soft;
layout(binding = 2) uniform sampler2D frosted;

float roundedBox(vec2 p, vec2 half_, float r) {
    vec2 q = abs(p) - half_ + r;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}
vec2 uvAt(vec2 px) { return area.xy + px / box * area.zw; }
float luma(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }
vec3 vivid(vec3 c, float amount) { return max(mix(vec3(luma(c)), c, amount), 0.0); }
vec3 capped(vec3 c, float top) { return c * min(1.0, top / max(luma(c), 0.0001)); }
vec3 screen(vec3 a, vec3 b) { return 1.0 - (1.0 - a) * (1.0 - b); }

void main() {
    vec2 p = qt_TexCoord0 * box;
    vec2 c = p - box * 0.5;
    vec2 h = box * 0.5;
    float d = roundedBox(c, h, corner);
    float inside = clamp(0.5 - d, 0.0, 1.0);
    // Outward direction of the nearest edge, and how far in this pixel is.
    vec2 n = normalize(vec2(roundedBox(c + vec2(1.0, 0.0), h, corner) - roundedBox(c - vec2(1.0, 0.0), h, corner),
                            roundedBox(c + vec2(0.0, 1.0), h, corner) - roundedBox(c - vec2(0.0, 1.0), h, corner)) + 1e-5);
    float depth = -d;
    vec3 caseColor = tint.rgb;

    // The body: vertical reeds 14 px apart, each magnifying and flipping a sliver of the blurred wallpaper.
    float s = fract(p.x / 14.0) * 2.0 - 1.0;
    vec3 body = texture(frosted, uvAt(vec2(p.x - s * 14.0 * 1.4 * reeds, p.y))).rgb;
    vec3 color = mix(capped(vivid(body, vibrance), ceiling), caseColor, cover);
    color *= 1.0 + reeds * (0.10 * sqrt(max(0.0, 1.0 - s * s)) - 0.07);

    // The bevel: what lies past the edge, bent in, with red, green and blue bent a little differently.
    float k = 1.0 - smoothstep(0.0, rim, depth);
    float bend = k * k * rim * 1.65;
    vec3 bent = vec3(texture(soft, uvAt(p + n * bend)).r,
                     texture(soft, uvAt(p + n * bend * 1.12)).g,
                     texture(soft, uvAt(p + n * bend * 1.26)).b);
    color = mix(color, mix(capped(vivid(bent, 1.4), ceiling * 1.5), caseColor, 0.5), smoothstep(0.0, 1.0, k));

    // Edge light: the wallpaper's colour just past the edge glows in the rim, more where the pointer is.
    float near = glow * exp(-length(p - pointer) / 140.0);
    vec3 beyond = vivid(texture(soft, uvAt(p + n * rim * 1.6)).rgb, 1.5) * 1.35;
    color = screen(color, beyond * pow(k, 3.0) * 0.45 * edgeGlow * (0.55 + near * 2.4));
    vec2 light = normalize(vec2(-0.45, -1.0));
    color += vec3(1.0) * (pow(max(dot(n, light), 0.0), 5.0) * k * k * 0.22 + near * k * k * 0.25);

    // The sheen: a thin film over the glass, in the accent with a little iridescence, along a band through the
    // pointer and on the rim.
    vec2 along = normalize(vec2(1.0, 0.55));
    float phase = dot(p, along) / 380.0 + length(p - pointer) / 520.0 + k * 0.35;
    vec3 film = mix(accent.rgb, 0.5 + 0.5 * cos(6.2831 * (phase + vec3(0.0, 0.33, 0.67))), 0.4);
    float band = exp(-pow(dot(p - pointer, along) / 90.0, 2.0));
    color = screen(color, film * glow * sheen * (band * 0.055 + k * k * 0.2 + near * 0.035));

    // The 1 px edge, lit by what lies beyond it; and a faint lip where the bevel meets the flat.
    float hairline = clamp(1.0 - abs(depth - 0.75) / 0.75, 0.0, 1.0);
    color = mix(color, screen(beyond * edgeGlow, vec3(0.22)), hairline * 0.55);
    color *= 1.0 - exp(-pow((depth - rim) / 3.0, 2.0)) * 0.14;
    fragColor = vec4(color, 1.0) * (inside * qt_Opacity);
}
