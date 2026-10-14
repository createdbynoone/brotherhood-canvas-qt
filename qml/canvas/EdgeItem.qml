import QtQuick
import QtQuick.Shapes

// One connection: a bezier from the model, an optional arrow head and label, and a cut button when it is the
// hovered or selected one. Stroke width scales with the world like every other node and edge.
Item {
    id: edge
    required property string edgeId
    required property real x1
    required property real y1
    required property real x2
    required property real y2
    required property real c1x
    required property real c1y
    required property real c2x
    required property real c2y
    required property real midX
    required property real midY
    required property string label
    required property string color
    required property real strokeWidth
    required property bool dashed
    required property bool arrow
    required property bool selected
    required property real endAngle
    required property bool arrowStart
    required property real startAngle
    required property int endCount
    required property bool endLead
    required property int startCount
    required property bool startLead
    required property string srcSide
    required property string dstSide

    readonly property bool hovered: Cam.hoverEdgeId === edgeId
    readonly property bool active: selected || hovered
    function solid(c, a) { const bg = Theme.bg; return Qt.rgba(bg.r + (c.r - bg.r) * a, bg.g + (c.g - bg.g) * a, bg.b + (c.b - bg.b) * a, 1) }
    readonly property color tone: selected ? Theme.accent
        : color.length > 0 ? color
        : hovered ? solid(Theme.text, 0.62) : solid(Theme.text, 0.40)

    // Line and heads read as one piece: the colour is opaque (a translucent line under a translucent head shows an
    // overlap), the line runs into the head's body, and each head is aimed along the *visible* approach (a point
    // ~1.4 head-lengths back), not the bezier's end tangent, which on a tight curve points somewhere else.
    readonly property real headBase: 8 + strokeWidth * 2
    function grown(n) { return headBase * Math.min(1.6, 1 + 0.3 * (n - 1)) }   // arrows sharing a side share one bigger head
    readonly property real headE: grown(endCount)
    readonly property real headS: grown(startCount)
    readonly property var geo: {
        const P = [[x1, y1], [c1x, c1y], [c2x, c2y], [x2, y2]]
        const lerp = (a, b, t) => [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t]
        const at = t => { const a = lerp(P[0], P[1], t), b = lerp(P[1], P[2], t), c = lerp(P[2], P[3], t), d = lerp(a, b, t), e = lerp(b, c, t); return [lerp(d, e, t), a, d, e, c] }
        const chord = Math.hypot(x2 - x1, y2 - y1)
        const solve = (dist, fromEnd) => {   // curve parameter whose distance from that end point is `dist`
            let lo = 0, hi = 1
            const p = fromEnd ? P[3] : P[0]
            for (let i = 0; i < 14; ++i) {
                const m = (lo + hi) / 2, q = at(m)[0], d = Math.hypot(q[0] - p[0], q[1] - p[1])
                if (fromEnd) { if (d > dist) lo = m; else hi = m } else { if (d < dist) lo = m; else hi = m }
            }
            return (lo + hi) / 2
        }
        const lookE = Math.min(headE * 1.4, chord * 0.4), cutE = Math.min(headE * 0.55, chord * 0.25)
        const lookS = Math.min(headS * 1.4, chord * 0.4), cutS = Math.min(headS * 0.55, chord * 0.25)
        const dir = (from, to) => { const dx = to[0] - from[0], dy = to[1] - from[1], l = Math.hypot(dx, dy) || 1; return [dx / l, dy / l] }
        let t0 = 0, t1 = 1, de = null, ds = null
        const normal = side => side === "left" ? [1, 0] : side === "right" ? [-1, 0] : side === "top" ? [0, 1] : [0, -1]
        const mergedE = arrow && endCount > 1, mergedS = arrowStart && startCount > 1
        if (arrow) { t1 = solve(cutE, true); de = mergedE ? normal(dstSide) : dir(at(solve(lookE, true))[0], P[3]) }
        if (arrowStart) { t0 = solve(cutS, false); ds = mergedS ? normal(srcSide) : dir(at(solve(lookS, false))[0], P[0]) }
        const deg = d => d ? Math.atan2(d[1], d[0]) * 180 / Math.PI : 0
        if (t1 - t0 < 0.05) return { q: P, ae: deg(de), as: deg(ds) }
        const s1 = at(t1)
        let q = [P[0], s1[1], s1[2], s1[0]]
        if (t0 > 0) {
            const u = t0 / t1
            const a = lerp(q[0], q[1], u), b = lerp(q[1], q[2], u), c = lerp(q[2], q[3], u), d = lerp(a, b, u), e = lerp(b, c, u)
            q = [lerp(d, e, u), e, c, q[3]]
        }
        if (de) q[3] = [P[3][0] - de[0] * cutE, P[3][1] - de[1] * cutE]      // finish exactly on the head's axis
        if (ds) q[0] = [P[0][0] - ds[0] * cutS, P[0][1] - ds[1] * cutS]
        // Lines that share a head all arrive along its axis, so they gather into the head instead of fanning out
        if (mergedE) { const r = Math.max(headE * 2.2, Math.hypot(q[3][0] - q[2][0], q[3][1] - q[2][1])); q[2] = [q[3][0] - de[0] * r, q[3][1] - de[1] * r] }
        if (mergedS) { const r = Math.max(headS * 2.2, Math.hypot(q[1][0] - q[0][0], q[1][1] - q[0][1])); q[1] = [q[0][0] - ds[0] * r, q[0][1] - ds[1] * r] }
        return { q: q, ae: deg(de), as: deg(ds) }
    }
    readonly property var curve: geo.q
    Shape {
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: "transparent"
            strokeColor: edge.tone
            strokeWidth: edge.strokeWidth + (edge.active ? 0.8 : 0)
            capStyle: ShapePath.FlatCap
            strokeStyle: edge.dashed ? ShapePath.DashLine : ShapePath.SolidLine
            dashPattern: [3, 2.5]
            startX: edge.curve[0][0]; startY: edge.curve[0][1]
            PathCubic { x: edge.curve[3][0]; y: edge.curve[3][1]; control1X: edge.curve[1][0]; control1Y: edge.curve[1][1]; control2X: edge.curve[2][0]; control2Y: edge.curve[2][1] }
        }
    }
    component Head: Shape {
        property real len: edge.headBase   // arrow head with its tip at (0, 0) pointing along +x, placed by x / y / rotation
        preferredRendererType: Shape.CurveRenderer
        transformOrigin: Item.TopLeft   // rotate about the tip, not about the middle of the shape's bounds
        ShapePath {
            id: ah
            readonly property real s: len
            fillColor: edge.tone
            strokeColor: "transparent"
            startX: 0; startY: 0
            PathLine { x: -ah.s; y: -ah.s * 0.46 }
            PathLine { x: -ah.s * 0.72; y: 0 }
            PathLine { x: -ah.s; y: ah.s * 0.46 }
            PathLine { x: 0; y: 0 }
        }
    }
    Head { visible: edge.arrow && edge.endLead; len: edge.headE; x: edge.x2; y: edge.y2; rotation: edge.geo.ae }          // target end
    Head { visible: edge.arrowStart && edge.startLead; len: edge.headS; x: edge.x1; y: edge.y1; rotation: edge.geo.as }   // source end
    Loader {   // label pill and cut button: only when there is a label or the edge is active
        active: edge.label.length > 0 || edge.active
        sourceComponent: Component {
            Item {
                readonly property real inv: 1 / Cam.zoom
                Rectangle {
                    visible: edge.label.length > 0
                    x: edge.midX - width / 2; y: edge.midY - height / 2 - (edge.active ? inv * 16 : 0)
                    width: lbl.implicitWidth + 18; height: 22; radius: 8
                    color: Theme.raised
                    border.width: inv; border.color: edge.selected ? Theme.alpha(Theme.accent, 0.7) : Theme.hairlineStrong
                    Txt { id: lbl; anchors.centerIn: parent; text: edge.label; variant: "label"; renderType: Text.QtRendering }
                }
                Rectangle {
                    visible: edge.active
                    x: edge.midX - width / 2; y: edge.midY - height / 2
                    width: inv * 24; height: width; radius: width / 2
                    color: Cam.hoverKind === "cut" && edge.hovered ? Theme.danger : Theme.elevated
                    border.width: inv; border.color: Theme.hairlineStrong
                    Icon { anchors.centerIn: parent; name: "scissors"; size: 14; scale: inv; color: Theme.text }
                }
            }
        }
    }
}
