import QtQuick
import QtQuick.Controls.Basic

Popup {
    id: root
    property string title: ""
    property string message: ""
    property string confirmText: "OK"
    property bool destructive: false
    signal confirmed()

    parent: Overlay.overlay
    anchors.centerIn: Overlay.overlay
    modal: true
    width: 380
    padding: 22
    closePolicy: Popup.CloseOnEscape
    Overlay.modal: Rectangle { color: Theme.scrim }
    background: Rectangle { radius: Theme.rPanel; color: Theme.surface; border.color: Theme.hairlineStrong }

    contentItem: Column {
        spacing: 12
        Txt { width: parent.width; text: root.title; variant: "title"; wrapMode: Text.Wrap }
        Txt { width: parent.width; text: root.message; dim: true; wrapMode: Text.Wrap }
        Item { width: 1; height: 4 }
        Row {
            anchors.right: parent.right
            spacing: 8
            Btn { kind: "secondary"; size: "m"; text: "Cancel"; onClicked: root.close() }
            Btn { kind: root.destructive ? "destructive" : "primary"; size: "m"; text: root.confirmText; onClicked: { root.close(); root.confirmed() } }
        }
    }
}
