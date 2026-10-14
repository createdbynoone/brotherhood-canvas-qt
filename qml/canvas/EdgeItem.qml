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

    readonly property bool hovered: Cam.hoverEdgeId === edgeId
    readonly property bool active: selected || hovered
    readonly property color tone: selected ? Theme.accent
        : color.length > 0 ? color
        : hovered ? Theme.alpha(Theme.text, 0.62) : Theme.alpha(Theme.text, 0.30)

    Shape {
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: "transparent"
            strokeColor: edge.tone
            strokeWidth: edge.strokeWidth + (edge.active ? 0.8 : 0)
            capStyle: ShapePath.RoundCap
            strokeStyle: edge.dashed ? ShapePath.DashLine : ShapePath.SolidLine
            dashPattern: [3, 2.5]
            startX: edge.x1; startY: edge.y1
            PathCubic { x: edge.x2; y: edge.y2; control1X: edge.c1x; control1Y: edge.c1y; control2X: edge.c2x; control2Y: edge.c2y }
        }
    }
    component Head: Shape {   // arrow head with its tip at (0, 0) pointing along +x, placed by x / y / rotation
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            id: ah
            readonly property real s: 8 + edge.strokeWidth * 2
            fillColor: edge.tone
            strokeColor: edge.tone
            strokeWidth: 0.6
            joinStyle: ShapePath.RoundJoin
            startX: 0; startY: 0
            PathLine { x: -ah.s; y: -ah.s * 0.5 }
            PathLine { x: -ah.s * 0.78; y: 0 }
            PathLine { x: -ah.s; y: ah.s * 0.5 }
            PathLine { x: 0; y: 0 }
        }
    }
    Head { visible: edge.arrow; x: edge.x2; y: edge.y2; rotation: edge.endAngle }          // target end
    Head { visible: edge.arrowStart; x: edge.x1; y: edge.y1; rotation: edge.startAngle }   // source end
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
