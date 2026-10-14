import QtQuick

// Floating editor for the selected connection: colour, weight, dashes, arrow head, label, delete.
Rectangle {
    id: root
    property bool shown: false
    signal labelClicked()

    property var info: ({})
    function refresh() { info = board.selectedEdge !== "" ? board.edgeInfo(board.selectedEdge) : ({}) }
    Connections { target: board; function onSelectionChanged() { root.refresh() } function onModified() { root.refresh() } function onBoundsChanged() { root.refresh() } }
    Component.onCompleted: refresh()

    visible: opacity > 0.01 && board.selectedEdge !== ""
    opacity: shown ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: Theme.fast } }
    width: row.implicitWidth + 16
    height: 40
    radius: Theme.rCard
    color: Theme.elevated
    border.color: Theme.hairlineStrong
    x: Math.max(Cam.insetLeft + 8, Math.min(parent.width - width - 8, Cam.sx(info.midX === undefined ? 0 : info.midX) - width / 2))
    y: Math.max(8, Math.min(parent.height - height - 90, Cam.sy(info.midY === undefined ? 0 : info.midY) - height - 24))

    component Sep: Rectangle { width: 1; height: 18; color: Theme.hairline; anchors.verticalCenter: parent.verticalCenter }

    Row {
        id: row
        x: 8; anchors.verticalCenter: parent.verticalCenter
        spacing: 4
        Repeater {
            model: Theme.edgeColors
            delegate: Rectangle {
                required property string modelData
                width: 16; height: 16; radius: 8
                anchors.verticalCenter: parent.verticalCenter
                color: modelData.length > 0 ? modelData : Theme.alpha(Theme.text, 0.35)
                border.width: root.info.color === modelData ? 2 : 0
                border.color: Theme.text
                HoverHandler { cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: board.setEdgeProp(board.selectedEdge, "color", modelData) }
            }
        }
        Sep {}
        Repeater {
            model: [{ w: 1, h: 1 }, { w: 1.5, h: 2 }, { w: 3, h: 3.5 }]
            delegate: Rectangle {
                required property var modelData
                readonly property bool on: Math.abs((root.info.strokeWidth === undefined ? 1.5 : root.info.strokeWidth) - modelData.w) < 0.1
                width: 28; height: 28; radius: Theme.rControl - 2
                anchors.verticalCenter: parent.verticalCenter
                color: on ? Theme.accentSoft : hv.hovered ? Qt.rgba(1, 1, 1, 0.06) : "transparent"
                Rectangle { anchors.centerIn: parent; width: 14; height: modelData.h; radius: modelData.h / 2; color: parent.on ? Theme.accent : Theme.textDim }
                HoverHandler { id: hv; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: board.setEdgeProp(board.selectedEdge, "strokeWidth", modelData.w) }
            }
        }
        Sep {}
        Btn { kind: "ghost"; size: "s"; icon: "dots-six"; tip: "Dashed line"; tint: "transparent"; onClicked: board.setEdgeProp(board.selectedEdge, "dashed", root.info.dashed ? null : true); opacity: 1; anchors.verticalCenter: parent.verticalCenter
              Rectangle { anchors.fill: parent; radius: Theme.rControl; color: Theme.accentSoft; visible: root.info.dashed === true; z: -1 } }
        Btn { kind: "ghost"; size: "s"; icon: "arrow-right"; tip: "Arrow head"; onClicked: board.setEdgeProp(board.selectedEdge, "arrow", root.info.arrow ? null : true); anchors.verticalCenter: parent.verticalCenter
              Rectangle { anchors.fill: parent; radius: Theme.rControl; color: Theme.accentSoft; visible: root.info.arrow === true; z: -1 } }
        Btn { kind: "ghost"; size: "s"; icon: "tag"; tip: "Label"; onClicked: root.labelClicked(); anchors.verticalCenter: parent.verticalCenter }
        Sep {}
        Btn { kind: "ghost"; size: "s"; icon: "trash"; tip: "Delete connection"; hint: "Del"; onClicked: board.deleteEdge(board.selectedEdge); anchors.verticalCenter: parent.verticalCenter }
    }
    MouseArea { anchors.fill: parent; z: -1; acceptedButtons: Qt.AllButtons; onWheel: w => w.accepted = true }
}
