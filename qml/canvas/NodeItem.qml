import QtQuick
import QtQuick.Shapes

// One self, drawn in world units inside the scaled world layer. It is passive: all pointer input is handled once,
// in CanvasView, which hit-tests against the model. Chrome (selection ring, grips, connection handles) is sized
// by 1/zoom so it stays the same on screen at any zoom.
Item {
    id: self
    required property int index
    required property string nodeId
    required property string nodeType
    required property real posX
    required property real posY
    required property real boxW
    required property real boxH
    required property bool selected
    required property string content
    required property string label
    required property bool locked
    required property string filePath
    required property string fileAbs
    required property string fileName
    required property real fileSize
    required property string thumbPath
    required property string noteColor
    required property int fontSize
    required property string sBg
    required property string sBorder
    required property real sBorderW
    required property real sRadius
    required property real sOpacity
    required property bool hasStyle
    required property bool editing

    x: posX; y: posY; width: boxW; height: boxH
    z: index
    opacity: sOpacity >= 0 ? sOpacity : 1

    readonly property bool tiny: width * Cam.zoomQ < 30
    // Text this small cannot be read: draw bars instead of laying out a document (the cost of an overview of a big board)
    readonly property bool textTiny: (nodeType === "text" || nodeType === "note") && Cam.zoomQ * 13 < 5.2
    readonly property bool isTitle: nodeType === "title"
    readonly property bool isNote: nodeType === "note"
    readonly property bool isMedia: nodeType === "image" || nodeType === "video"
    readonly property real radiusPx: sRadius >= 0 ? sRadius : (isNote ? 4 : Theme.rCard)
    // Notes are sticky notes: filled with their colour (or the style fill), ink picked by luminance
    readonly property color noteFill: sBg.length > 0 ? sBg : noteColor
    readonly property color noteInk: {
        const c = Qt.color(noteFill)
        return (0.299 * c.r + 0.587 * c.g + 0.114 * c.b) > 0.5 ? "#1A1713" : "#F5F1E8"
    }
    readonly property bool hovered: Cam.hoverId === nodeId && !Cam.connecting
    readonly property bool dropTarget: Cam.connecting && Cam.connectTarget === nodeId
    readonly property bool single: selected && board.selectedCount === 1
    readonly property bool showHandles: (hovered || single || dropTarget) && !editing
    readonly property bool hasLabelStrip: label.length > 0 && !isTitle && !isNote

    function primaryAction() { if (nodeType === "video" && body.item && body.item.primaryAction) body.item.primaryAction() }

    // Sticky note: paper with the bottom-right corner folded up (cut corner + the flap), over a soft shadow
    readonly property real fold: Math.max(8, Math.min(26, width * 0.22, height * 0.3))
    Shape {
        visible: self.isNote
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {   // shadow
            fillColor: Qt.rgba(0, 0, 0, 0.34); strokeColor: "transparent"
            startX: 0; startY: 5
            PathLine { x: self.width; y: 5 }
            PathLine { x: self.width; y: self.height - self.fold + 5 }
            PathLine { x: self.width - self.fold; y: self.height + 5 }
            PathLine { x: 0; y: self.height + 5 }
        }
        ShapePath {   // paper
            fillColor: self.noteFill; strokeColor: self.sBorder.length > 0 ? self.sBorder : "transparent"
            strokeWidth: self.sBorder.length > 0 ? (self.sBorderW >= 0 ? self.sBorderW : 1) : 0
            startX: 0; startY: 0
            PathLine { x: self.width; y: 0 }
            PathLine { x: self.width; y: self.height - self.fold }
            PathLine { x: self.width - self.fold; y: self.height }
            PathLine { x: 0; y: self.height }
            PathLine { x: 0; y: 0 }
        }
        ShapePath {   // the lifted flap: the paper's lighter back
            fillGradient: LinearGradient {
                x1: self.width - self.fold; y1: self.height - self.fold; x2: self.width; y2: self.height
                GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0.34) }
                GradientStop { position: 1; color: Qt.rgba(1, 1, 1, 0.08) }
            }
            strokeColor: "transparent"
            startX: self.width; startY: self.height - self.fold
            PathLine { x: self.width - self.fold; y: self.height }
            PathLine { x: self.width - self.fold; y: self.height - self.fold }
            PathLine { x: self.width; y: self.height - self.fold }
        }
    }
    // Fill
    Rectangle {
        visible: !self.isTitle && !self.isNote
        anchors.fill: parent
        radius: self.radiusPx
        color: self.sBg.length > 0 ? self.sBg
             : self.nodeType === "image" ? "transparent"
             : self.nodeType === "video" ? Theme.raised
             : Theme.surface
    }
    // Tape-like highlight along the top edge of the paper
    Rectangle {
        visible: self.isNote
        x: 0; y: 0; width: parent.width; height: Math.min(parent.height, 26)
        radius: self.radiusPx
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0.14) }
            GradientStop { position: 1; color: Qt.rgba(1, 1, 1, 0) }
        }
    }

    Loader {
        id: body
        anchors.fill: parent
        anchors.bottomMargin: self.hasLabelStrip ? 24 : 0
        active: self.visible && !self.tiny && !self.textTiny
        sourceComponent: {
            switch (self.nodeType) {
            case "image": return imageC
            case "video": return videoC
            case "pdf": case "file": return pdfC
            case "title": return titleC
            default: return textC      // text, note
            }
        }
    }
    Column {   // stand-in for unreadable text
        visible: self.textTiny && !self.tiny
        x: 12; y: self.isNote ? 14 : 12
        width: parent.width - 24
        spacing: 10
        Repeater {
            model: self.content.length > 0 ? 4 : 0
            delegate: Rectangle {
                required property int index
                width: parent.width * (index === 0 ? 0.55 : index === 3 ? 0.4 : 0.9); height: 6; radius: 3
                color: Theme.alpha(self.isNote ? self.noteInk : Theme.text, index === 0 ? 0.30 : 0.14)
            }
        }
    }
    Component { id: imageC; ImageContent { node: self } }
    Component { id: videoC; VideoContent { node: self } }
    Component { id: pdfC; PdfContent { node: self } }
    Component { id: textC; TextContent { node: self } }
    Component { id: titleC; TitleContent { node: self } }

    // Label strip along the bottom (media, files, text cards); notes show it in their colour at the top
    Rectangle {
        visible: self.hasLabelStrip
        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        height: 24
        radius: self.radiusPx * 0.5
        color: Theme.alpha(Theme.bg, 0.86)
        Txt {
            anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10
            verticalAlignment: Text.AlignVCenter
            text: self.label; variant: "overline"; font.pixelSize: 10; dim: true
            elide: Text.ElideRight; renderType: Text.QtRendering
        }
    }
    Txt {
        visible: self.isNote && self.label.length > 0
        x: 14; y: 8; width: parent.width - 28
        text: self.label; variant: "overline"; font.pixelSize: 10
        color: self.noteInk; opacity: 0.6; elide: Text.ElideRight; renderType: Text.QtRendering
    }

    // Border over the content
    Rectangle {
        visible: !self.isTitle && !self.isNote
        anchors.fill: parent
        radius: self.radiusPx
        color: "transparent"
        border.width: self.sBorderW >= 0 ? self.sBorderW : 1
        border.color: self.sBorder.length > 0 ? self.sBorder
                    : self.isNote ? Qt.rgba(0, 0, 0, 0.16)
                    : self.hovered || self.dropTarget ? Theme.hairlineStrong : Theme.alpha(Qt.rgba(1, 1, 1, 1), 0.11)
    }
    // Everything that needs the live zoom lives in a loader that exists only for the selected / hovered node
    Loader {
        anchors.fill: parent
        active: !Cam.exporting && (self.selected || self.dropTarget || self.hovered)
        sourceComponent: Component { NodeChrome { owner: self } }
    }
}
