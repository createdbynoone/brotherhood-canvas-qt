import QtQuick
import QtQuick.Controls.Basic

// Context menu in the app's own look. Fill it with MenuRow items (icon, shortcut hint, danger tone).
Menu {
    id: root
    padding: 6
    topPadding: 6; bottomPadding: 6
    implicitWidth: 224
    background: Rectangle {
        radius: Theme.rCard
        color: Theme.elevated
        border.color: Theme.hairlineStrong
    }
}
