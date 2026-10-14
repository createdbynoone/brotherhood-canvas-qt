import QtQuick

// Floating toolbar above the selection: arrange tools for several nodes, type-specific tools (title size, note
// colour) and the everyday actions for one. Screen space, so it keeps its size at any zoom.
Rectangle {
    id: root
    property bool shown: false
    signal styleClicked()
    signal labelClicked()

    readonly property bool multi: board.selectedCount > 1
    readonly property string type: board.selectedType
    property var info: ({})
    function refresh() { info = board.selectedCount === 1 ? board.nodeInfo(board.selectedId) : ({}) }
    Connections { target: board; function onSelectionChanged() { root.refresh() } function onModified() { root.refresh() } }
    Component.onCompleted: refresh()

    readonly property rect r: board.selectionBounds
    visible: opacity > 0.01 && board.selectedCount > 0
    opacity: shown ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: Theme.fast } }
    width: row.implicitWidth + 12
    height: 40
    radius: Theme.rCard
    color: Theme.elevated
    border.color: Theme.hairlineStrong
    x: Math.max(Cam.insetLeft + 8, Math.min(parent.width - width - 8, Cam.sx(r.x + r.width / 2) - width / 2))
    y: {
        const above = Cam.sy(r.y) - height - 16
        return above >= 8 ? above : Math.min(parent.height - height - 90, Cam.sy(r.y + r.height) + 16)
    }

    component Sep: Rectangle { width: 1; height: 18; color: Theme.hairline; anchors.verticalCenter: parent.verticalCenter }

    Row {
        id: row
        x: 6; anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        // Title: H1 / H2 / H3
        Repeater {
            model: !root.multi && root.type === "title" ? [{ l: "H1", s: 40 }, { l: "H2", s: 28 }, { l: "H3", s: 20 }] : []
            delegate: Rectangle {
                required property var modelData
                readonly property bool on: (modelData.s === 40 && root.info.fontSize >= 36) || (modelData.s === 28 && root.info.fontSize >= 24 && root.info.fontSize < 36) || (modelData.s === 20 && root.info.fontSize < 24)
                width: 32; height: 28; radius: Theme.rControl - 2
                color: on ? Theme.accentSoft : hov.hovered ? Qt.rgba(1, 1, 1, 0.06) : "transparent"
                anchors.verticalCenter: parent.verticalCenter
                Txt { anchors.centerIn: parent; text: modelData.l; variant: "strong"; font.pixelSize: 12; color: parent.on ? Theme.accent : Theme.textDim }
                HoverHandler { id: hov; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: board.setNodeData(board.selectedId, "fontSize", modelData.s) }
            }
        }
        // Note colour
        Row {
            visible: !root.multi && root.type === "note"
            spacing: 5
            leftPadding: 6; rightPadding: 6
            anchors.verticalCenter: parent.verticalCenter
            Repeater {
                model: Theme.noteColors
                delegate: Rectangle {
                    required property string modelData
                    width: 16; height: 16; radius: 8
                    anchors.verticalCenter: parent.verticalCenter
                    color: modelData
                    border.width: root.info.noteColor === modelData ? 2 : 0
                    border.color: Theme.text
                    scale: nh.hovered ? 1.15 : 1
                    Behavior on scale { NumberAnimation { duration: Theme.fast } }
                    HoverHandler { id: nh; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: board.setNodeData(board.selectedId, "noteColor", modelData) }
                }
            }
        }
        Sep { visible: !root.multi && (root.type === "title" || root.type === "note") }

        // Several nodes: arrange
        Repeater {
            model: root.multi ? [
                { i: "align-left", t: "Align left", a: "left" }, { i: "align-center-horizontal", t: "Align centers", a: "hcenter" },
                { i: "align-right", t: "Align right", a: "right" }, { i: "align-top", t: "Align top", a: "top" },
                { i: "align-center-vertical", t: "Align middles", a: "vcenter" }, { i: "align-bottom", t: "Align bottom", a: "bottom" }
            ] : []
            delegate: Btn { required property var modelData; kind: "ghost"; size: "s"; icon: modelData.i; tip: modelData.t; onClicked: board.align(modelData.a); anchors.verticalCenter: parent.verticalCenter }
        }
        Sep { visible: root.multi }
        Btn { visible: root.multi; kind: "ghost"; size: "s"; icon: "arrows-out-line-horizontal"; tip: "Distribute horizontally"; enabled: board.selectedCount > 2; onClicked: board.distribute("h"); anchors.verticalCenter: parent.verticalCenter }
        Btn { visible: root.multi; kind: "ghost"; size: "s"; icon: "arrows-out-line-vertical"; tip: "Distribute vertically"; enabled: board.selectedCount > 2; onClicked: board.distribute("v"); anchors.verticalCenter: parent.verticalCenter }
        Btn { visible: root.multi; kind: "ghost"; size: "s"; icon: "squares-four"; tip: "Tidy into a grid"; onClicked: board.tidy(); anchors.verticalCenter: parent.verticalCenter }
        Sep { visible: root.multi }

        // Everyday
        Btn { visible: !root.multi; kind: "ghost"; size: "s"; icon: "palette"; tip: "Style"; onClicked: root.styleClicked(); anchors.verticalCenter: parent.verticalCenter }
        Btn { visible: !root.multi && root.type !== "title"; kind: "ghost"; size: "s"; icon: "tag"; tip: "Label"; onClicked: root.labelClicked(); anchors.verticalCenter: parent.verticalCenter }
        Btn { kind: "ghost"; size: "s"; icon: board.hasSelectionLocked ? "lock" : "lock-open"; iconWeight: board.hasSelectionLocked ? "fill" : "regular"; tip: board.hasSelectionLocked ? "Unlock" : "Lock position"; hint: "⌘L"; onClicked: board.setLocked(!board.hasSelectionLocked); anchors.verticalCenter: parent.verticalCenter }
        Btn { kind: "ghost"; size: "s"; icon: "copy-simple"; tip: "Duplicate"; hint: "⌘D"; onClicked: board.duplicateSelected(); anchors.verticalCenter: parent.verticalCenter }
        Btn { kind: "ghost"; size: "s"; icon: "arrow-line-up"; tip: "Bring to front"; hint: "⌘]"; onClicked: board.bringToFront(); anchors.verticalCenter: parent.verticalCenter }
        Btn { kind: "ghost"; size: "s"; icon: "arrow-line-down"; tip: "Send to back"; hint: "⌘["; onClicked: board.sendToBack(); anchors.verticalCenter: parent.verticalCenter }
        Sep {}
        Btn { kind: "ghost"; size: "s"; icon: "trash"; tip: "Delete"; hint: "Del"; onClicked: board.deleteSelected(); anchors.verticalCenter: parent.verticalCenter }
    }
    MouseArea { anchors.fill: parent; z: -1; acceptedButtons: Qt.AllButtons; onWheel: w => w.accepted = true }
}
