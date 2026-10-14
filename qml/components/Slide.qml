import QtQuick

// Thin slider with a value readout. Reports `moved(v)` while dragging and `released()` at the end.
Item {
    id: root
    property real from: 0
    property real to: 1
    property real value: 0
    property real step: 0
    property string unit: ""
    property int decimals: 0
    property bool active: false          // false: the value is the default, drawn muted
    property bool readout: true
    signal moved(real v)
    signal started()
    signal released()

    implicitHeight: 28
    implicitWidth: 200

    readonly property real frac: to > from ? Math.max(0, Math.min(1, (value - from) / (to - from))) : 0
    function setFromX(x) {
        let v = from + Math.max(0, Math.min(1, (x - track.x) / track.width)) * (to - from)
        if (step > 0) v = Math.round(v / step) * step
        moved(v)
    }

    Rectangle {
        id: track
        x: 0; width: parent.width - (root.readout ? 52 : 0)
        height: 4; radius: 2
        anchors.verticalCenter: parent.verticalCenter
        color: Theme.hairlineStrong
        Rectangle { width: parent.width * root.frac; height: parent.height; radius: 2; color: root.active ? Theme.accent : Theme.textMuted }
        Rectangle {
            x: parent.width * root.frac - width / 2; anchors.verticalCenter: parent.verticalCenter
            width: 14; height: 14; radius: 7
            color: Theme.text
            border.color: Theme.bg; border.width: 2
            scale: drag.active ? 1.15 : 1
            Behavior on scale { NumberAnimation { duration: Theme.fast } }
        }
    }
    Txt {
        visible: root.readout
        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
        text: root.value.toFixed(root.decimals) + root.unit
        variant: "mono"; dim: true
    }
    MouseArea {
        anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
        width: track.width
        preventStealing: true
        cursorShape: Qt.PointingHandCursor
        onPressed: m => { drag.active = true; root.started(); root.setFromX(m.x) }
        onPositionChanged: m => { if (pressed) root.setFromX(m.x) }
        onReleased: { drag.active = false; root.released() }
        QtObject { id: drag; property bool active: false }
    }
}
