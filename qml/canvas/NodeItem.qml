import QtQuick

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
    readonly property real radiusPx: sRadius >= 0 ? sRadius : (isNote ? 14 : Theme.rCard)
    readonly property bool hovered: Cam.hoverId === nodeId && !Cam.connecting
    readonly property bool dropTarget: Cam.connecting && Cam.connectTarget === nodeId
    readonly property bool single: selected && board.selectedCount === 1
    readonly property bool showHandles: (hovered || single || dropTarget) && !editing
    readonly property bool hasLabelStrip: label.length > 0 && !isTitle && !isNote

    function primaryAction() { if (nodeType === "video" && body.item && body.item.primaryAction) body.item.primaryAction() }

    // Fill
    Rectangle {
        visible: !self.isTitle
        anchors.fill: parent
        radius: self.radiusPx
        color: self.sBg.length > 0 ? self.sBg
             : self.isNote ? Theme.alpha(Theme.raised, 0.92)
             : self.nodeType === "image" ? "transparent"
             : self.nodeType === "video" ? Theme.raised
             : Theme.surface
    }
    // Note colour strip
    Rectangle {
        visible: self.isNote
        x: self.radiusPx * 0.35; y: 0
        width: parent.width - self.radiusPx * 0.7; height: 3
        radius: 1.5
        color: self.noteColor
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
                color: Theme.alpha(Theme.text, index === 0 ? 0.30 : 0.14)
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
        color: self.noteColor; elide: Text.ElideRight; renderType: Text.QtRendering
    }

    // Border over the content
    Rectangle {
        visible: !self.isTitle
        anchors.fill: parent
        radius: self.radiusPx
        color: "transparent"
        border.width: self.sBorderW >= 0 ? self.sBorderW : 1
        border.color: self.sBorder.length > 0 ? self.sBorder
                    : self.isNote ? Theme.alpha(self.noteColor, 0.30)
                    : self.hovered || self.dropTarget ? Theme.hairlineStrong : Theme.alpha(Qt.rgba(1, 1, 1, 1), 0.11)
    }
    // Everything that needs the live zoom lives in a loader that exists only for the selected / hovered node
    Loader {
        anchors.fill: parent
        active: self.selected || self.dropTarget || self.hovered
        sourceComponent: Component { NodeChrome { owner: self } }
    }
}
