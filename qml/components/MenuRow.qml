import QtQuick
import QtQuick.Controls.Basic

MenuItem {
    id: item
    property string glyph: ""
    property string hint: ""
    property bool danger: false
    implicitHeight: 30
    implicitWidth: 212
    leftPadding: 10; rightPadding: 10
    indicator: Item {}
    contentItem: Item {
        Icon {
            visible: item.glyph.length > 0
            name: item.glyph; size: 15
            color: !item.enabled ? Theme.textMuted : item.danger ? Theme.danger : Theme.textDim
            anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
        }
        Txt {
            text: item.text
            variant: "small"; font.pixelSize: 13
            color: !item.enabled ? Theme.textMuted : item.danger ? Theme.danger : Theme.text
            anchors.left: parent.left; anchors.leftMargin: item.glyph.length > 0 ? 24 : 0
            anchors.verticalCenter: parent.verticalCenter
        }
        Txt {
            visible: item.hint.length > 0
            text: item.hint; variant: "mono"; muted: true
            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
        }
    }
    background: Rectangle {
        radius: Theme.rControl - 2
        color: item.highlighted && item.enabled ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
    }
}
