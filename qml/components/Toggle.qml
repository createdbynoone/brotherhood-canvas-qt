import QtQuick

// On / off switch.
Rectangle {
    id: root
    property bool checked: false
    signal toggled(bool value)
    implicitWidth: 38; implicitHeight: 22
    radius: 11
    color: checked ? Theme.accent : Theme.elevated
    border.color: checked ? Theme.accent : Theme.hairlineStrong
    Behavior on color { ColorAnimation { duration: Theme.fast } }
    Rectangle {
        width: 16; height: 16; radius: 8
        y: 3; x: root.checked ? parent.width - width - 3 : 3
        color: root.checked ? Theme.accentInk : Theme.textDim
        Behavior on x { NumberAnimation { duration: Theme.fast; easing.type: Easing.OutCubic } }
    }
    HoverHandler { cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: root.toggled(!root.checked) }
}
