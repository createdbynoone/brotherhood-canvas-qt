import QtQuick
import QtQuick.Controls.Basic

ScrollBar {
    id: bar
    implicitWidth: 10
    padding: 2
    contentItem: Rectangle {
        implicitWidth: 6
        radius: 3
        color: bar.pressed ? Theme.textDim : bar.hovered ? Theme.textMuted : Theme.alpha(Theme.textMuted, 0.55)
        opacity: bar.size < 1 && (bar.active || bar.hovered || bar.pressed) ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.base } }
    }
    background: Item {}
}
