import QtQuick
import QtQuick.Shapes
import "../core"

// Breaks `source` (a texture provider the size of this item, such as a ShaderEffectSource) into glass shards
// along cracks that run out from `impact` and rings around it, like tempered glass: small pieces near the hit,
// large ones far from it. start() runs it: a white flash at the impact while the cracks race out, then the shards
// give way in a wave from the hit, flying outward, tumbling and catching the light as they fall and fade.
// `running` is true until it ends; `finished` fires then. Each piece is drawn once and only moved after that.
Item {
    id: root
    property Item source: null
    property point impact: Qt.point(width / 2, height / 2)
    property int rays: 14
    // Ring radii as fractions of the distance from the impact to the farthest corner.
    property var rings: [0.025, 0.06, 0.11, 0.19, 0.3, 0.46, 0.68, 1.05]
    // How long each shard flies, and how far behind the hit the farthest one starts.
    readonly property real flight: Theme.ms(720)
    readonly property real reachTime: Theme.ms(480)
    readonly property real total: reachTime + flight + Theme.ms(90)
    property real burst: 0
    property var shards: []
    readonly property bool running: run.running
    signal finished()
    // Time since the hit, in ms.
    readonly property real now: burst * total
    function rand(seed) {
        const x = Math.sin(seed * 12.9898 + 78.233) * 43758.5453;
        return x - Math.floor(x);
    }
    // The part of a polygon inside this item (Sutherland–Hodgman, one edge of the item at a time).
    function clipToBox(poly) {
        const w = width, h = height;
        const edges = [[p => p.x >= 0, (a, b) => ({x: 0, y: a.y + (b.y - a.y) * (0 - a.x) / (b.x - a.x)})],
                       [p => p.x <= w, (a, b) => ({x: w, y: a.y + (b.y - a.y) * (w - a.x) / (b.x - a.x)})],
                       [p => p.y >= 0, (a, b) => ({x: a.x + (b.x - a.x) * (0 - a.y) / (b.y - a.y), y: 0})],
                       [p => p.y <= h, (a, b) => ({x: a.x + (b.x - a.x) * (h - a.y) / (b.y - a.y), y: h})]];
        let out = poly;
        for (const [inside, cut] of edges) {
            const input = out;
            out = [];
            for (let i = 0; i < input.length; i++) {
                const a = input[i], b = input[(i + 1) % input.length];
                if (inside(b)) {
                    if (!inside(a))
                        out.push(cut(a, b));
                    out.push(b);
                } else if (inside(a)) {
                    out.push(cut(a, b));
                }
            }
            if (!out.length)
                break;
        }
        return out;
    }
    function build() {
        const p = impact, list = [];
        const reach = Math.max(Math.hypot(p.x, p.y), Math.hypot(width - p.x, p.y), Math.hypot(p.x, height - p.y), Math.hypot(width - p.x, height - p.y));
        // A different break each time.
        const seed = Math.random() * 1000;
        const angles = [];
        for (let i = 0; i < rays; i++)
            angles.push((i + (rand(seed + i + 1) - 0.5) * 0.7) / rays * Math.PI * 2);
        const vertex = (i, j) => {
            if (j === 0)
                return {x: p.x, y: p.y};
            const a = angles[i % rays] + (rand(seed + i * 31 + j * 7) - 0.5) * 0.12;
            // The last ring lies past every corner, so the pieces always cover the whole item.
            const r = j === rings.length ? reach * 1.5 : rings[j - 1] * reach * (0.85 + rand(seed + i * 13 + j * 17) * 0.3);
            return {x: p.x + Math.cos(a) * r, y: p.y + Math.sin(a) * r};
        };
        for (let i = 0; i < rays; i++) {
            for (let j = 0; j < rings.length; j++) {
                const quad = [vertex(i, j), vertex(i + 1, j), vertex(i + 1, j + 1), vertex(i, j + 1)];
                // Larger pieces further out split once along a diagonal.
                const parts = j >= 2 && rand(seed + i * 5 + j) > 0.35 ? [[quad[0], quad[1], quad[2]], [quad[0], quad[2], quad[3]]]
                                                                       : [j === 0 ? [quad[0], quad[2], quad[3]] : quad];
                for (const part of parts) {
                    const poly = clipToBox(part);
                    if (poly.length < 3)
                        continue;
                    const cx = poly.reduce((s, q) => s + q.x, 0) / poly.length, cy = poly.reduce((s, q) => s + q.y, 0) / poly.length;
                    const dx = cx - p.x, dy = cy - p.y, d = Math.max(1, Math.hypot(dx, dy));
                    const k = seed + list.length;
                    list.push({poly: poly.concat([poly[0]]).map(q => Qt.point(q.x, q.y)), cx: cx, cy: cy, dx: dx / d, dy: dy / d,
                               delay: Theme.ms(90) + d / reach * root.reachTime, crack: d / reach * Theme.ms(80),
                               fling: 50 + rand(k * 3.1) * 110, spin: (rand(k * 7.7) - 0.5) * 70, drop: 260 + rand(k * 1.3) * 260,
                               tumble: (rand(k * 2.3) - 0.5) * 150, ax: rand(k * 4.1) - 0.5, ay: rand(k * 6.7) - 0.5});
                }
            }
        }
        shards = list;
    }
    function start() {
        build();
        burst = 0;
        run.restart();
    }
    NumberAnimation {
        id: run
        target: root
        property: "burst"
        from: 0
        to: 1
        duration: root.total
        onFinished: {
            root.shards = [];
            root.finished();
        }
    }
    Repeater {
        model: root.shards
        Shape {
            id: piece
            required property var modelData
            readonly property real t: Math.max(0, Math.min(1, (root.now - modelData.delay) / root.flight))
            readonly property real out: 1 - Math.pow(1 - t, 3)
            // How far the face has turned toward the light while it tumbles.
            readonly property real tilt: Math.abs(Math.sin(modelData.tumble * out * Math.PI / 180))
            // The crack reaches this piece a moment after the hit, racing out from the impact.
            readonly property real cracked: Math.max(0, Math.min(1, (root.now - modelData.crack) / Theme.ms(30)))
            width: root.width
            height: root.height
            preferredRendererType: Shape.CurveRenderer
            opacity: 1 - Math.max(0, (t - 0.55) / 0.45)
            transform: [
                Rotation { origin.x: piece.modelData.cx; origin.y: piece.modelData.cy; angle: piece.modelData.spin * piece.out },
                Rotation {
                    origin.x: piece.modelData.cx
                    origin.y: piece.modelData.cy
                    axis { x: piece.modelData.ax; y: piece.modelData.ay; z: 0 }
                    angle: piece.modelData.tumble * piece.out
                },
                Scale { origin.x: piece.modelData.cx; origin.y: piece.modelData.cy; xScale: 1 - 0.12 * piece.t; yScale: xScale },
                Translate {
                    x: piece.modelData.dx * piece.modelData.fling * piece.out
                    y: piece.modelData.dy * piece.modelData.fling * piece.out + piece.modelData.drop * piece.t * piece.t
                }
            ]
            ShapePath {
                strokeWidth: 0.7
                strokeColor: Qt.rgba(1, 1, 1, 0.38 * piece.cracked * (1 - piece.t))
                fillItem: root.source
                PathPolyline { path: piece.modelData.poly }
            }
            ShapePath {
                strokeWidth: 0
                strokeColor: "transparent"
                fillColor: Qt.rgba(1, 1, 1, 0.16 * piece.tilt)
                PathPolyline { path: piece.modelData.poly }
            }
        }
    }
    // The hit: a brief white flash at the impact.
    Rectangle {
        readonly property real flash: Math.max(0, Math.min(1, root.now / Theme.ms(170)))
        x: root.impact.x - width / 2
        y: root.impact.y - height / 2
        width: 30 + 160 * flash
        height: width
        radius: width / 2
        visible: root.running && flash < 1
        opacity: 0.5 * (1 - flash)
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0) }
            GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 1) }
            GradientStop { position: 1; color: Qt.rgba(1, 1, 1, 0) }
        }
    }
}
