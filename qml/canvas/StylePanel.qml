import QtQuick
import QtQuick.Controls.Basic

// Floating, draggable style panel for the selected node: presets, note colour, fill, border, radius, opacity.
Rectangle {
    id: root
    signal closed()
    width: 288
    height: Math.min(body.implicitHeight + 46, parent.height - y - 90)
    radius: Theme.rPanel
    color: Theme.alpha(Theme.surface, 0.97)
    border.color: Theme.hairlineStrong
    clip: true

    property var info: ({})
    readonly property string id: board.selectedId
    function refresh() { info = board.selectedCount === 1 ? board.nodeInfo(board.selectedId) : ({}) }
    Connections { target: board; function onSelectionChanged() { root.refresh() } function onModified() { root.refresh() } }
    Component.onCompleted: refresh()

    // Header, also the drag handle
    Item {
        id: head
        width: parent.width; height: 44
        Txt { text: "Style"; variant: "heading"; font.pixelSize: 13; anchors.left: parent.left; anchors.leftMargin: 14; anchors.verticalCenter: parent.verticalCenter }
        Row {
            anchors.right: parent.right; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            Btn { visible: root.info.hasStyle === true; kind: "ghost"; size: "xs"; text: "Reset"; onClicked: board.resetStyle(root.id) }
            Btn { kind: "ghost"; size: "xs"; icon: "x"; onClicked: root.closed() }
        }
        Hairline { anchors.bottom: parent.bottom }
        DragHandler {
            target: root
            xAxis.minimum: 8; xAxis.maximum: root.parent.width - root.width - 8
            yAxis.minimum: 8; yAxis.maximum: root.parent.height - 120
            cursorShape: Qt.SizeAllCursor
        }
    }

    Flickable {
        y: head.height + 1
        width: parent.width; height: parent.height - head.height - 1
        contentWidth: width; contentHeight: body.implicitHeight + 12
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: StudioScrollBar {}

        Column {
            id: body
            x: 14; y: 12
            width: parent.width - 28
            spacing: 14

            component Label_: Txt { variant: "label"; muted: true }

            Column {
                width: parent.width; spacing: 8
                Label_ { text: "Presets" }
                Grid {
                    columns: 3; spacing: 6; width: parent.width
                    Repeater {
                        model: Theme.presets
                        delegate: Rectangle {
                            required property var modelData
                            readonly property bool on: root.info.sBg === modelData.bg && root.info.sBorder === modelData.border
                            width: (body.width - 12) / 3; height: 58; radius: Theme.rControl
                            color: on ? Theme.accentSoft : ph.hovered ? Theme.raised : "transparent"
                            border.color: on ? Theme.alpha(Theme.accent, 0.5) : Theme.hairline
                            Rectangle {
                                x: (parent.width - width) / 2; y: 8; width: 30; height: 24; radius: 6
                                color: modelData.bg === "transparent" ? "transparent" : modelData.bg
                                border.width: 2; border.color: modelData.border
                            }
                            Txt { y: 38; width: parent.width; horizontalAlignment: Text.AlignHCenter; text: modelData.label; variant: "caption"; color: parent.on ? Theme.accent : Theme.textDim }
                            HoverHandler { id: ph; cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: board.applyPreset(root.id, modelData.bg, modelData.border) }
                        }
                    }
                }
            }
            Column {
                visible: root.info.type === "note"
                width: parent.width; spacing: 8
                Label_ { text: "Note colour" }
                Flow {
                    width: parent.width; spacing: 8
                    Repeater {
                        model: Theme.noteColors
                        delegate: Rectangle {
                            required property string modelData
                            width: 24; height: 24; radius: 12
                            color: modelData
                            border.width: root.info.noteColor === modelData ? 2 : 0; border.color: Theme.text
                            HoverHandler { cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: board.setNodeData(root.id, "noteColor", modelData) }
                        }
                    }
                }
            }
            Column {
                width: parent.width; spacing: 8
                Label_ { text: "Fill" }
                ColorField { width: parent.width; value: root.info.sBg ? root.info.sBg : ""; fallback: root.info.type === "image" ? "transparent" : "#111110"; onPicked: hex => hex.length ? board.setStyle(root.id, "backgroundColor", hex) : board.setStyle(root.id, "backgroundColor", null) }
            }
            Column {
                width: parent.width; spacing: 8
                Label_ { text: "Border" }
                ColorField { width: parent.width; value: root.info.sBorder ? root.info.sBorder : ""; fallback: "#2A2A28"; onPicked: hex => hex.length ? board.setStyle(root.id, "borderColor", hex) : board.setStyle(root.id, "borderColor", null) }
                Slide {
                    width: parent.width; from: 0; to: 12; step: 1
                    value: root.info.sBorderW >= 0 ? root.info.sBorderW : 1; active: root.info.sBorderW >= 0
                    onStarted: board.beginGesture()
                    onMoved: v => board.setStyle(root.id, "borderWidth", v)
                    onReleased: board.endGesture()
                }
            }
            Column {
                width: parent.width; spacing: 4
                Label_ { text: "Corner radius" }
                Slide {
                    width: parent.width; from: 0; to: 48; step: 1
                    value: root.info.sRadius >= 0 ? root.info.sRadius : (root.info.type === "note" ? 14 : 12); active: root.info.sRadius >= 0
                    onStarted: board.beginGesture()
                    onMoved: v => board.setStyle(root.id, "borderRadius", v)
                    onReleased: board.endGesture()
                }
            }
            Column {
                width: parent.width; spacing: 4
                Label_ { text: "Opacity" }
                Slide {
                    width: parent.width; from: 5; to: 100; step: 1; unit: "%"
                    value: root.info.sOpacity >= 0 ? Math.round(root.info.sOpacity * 100) : 100; active: root.info.sOpacity >= 0
                    onStarted: board.beginGesture()
                    onMoved: v => board.setStyle(root.id, "opacity", v >= 100 ? null : v / 100)
                    onReleased: board.endGesture()
                }
            }
        }
    }
    MouseArea { anchors.fill: parent; z: -1; acceptedButtons: Qt.AllButtons; onWheel: w => w.accepted = true }
}
