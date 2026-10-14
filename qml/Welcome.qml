import QtQuick
import QtQuick.Dialogs

// First launch, or the vault is missing: create a vault or open an existing one.
Rectangle {
    id: root
    color: Theme.bg

    FolderDialog { id: openPicker; title: "Choose a Brotherhood Canvas vault"; onAccepted: canvas.openVault(app.localPath(selectedFolder)) }
    FolderDialog { id: createPicker; title: "Choose a folder for the new vault"; onAccepted: canvas.createVault(app.localPath(selectedFolder)) }

    Column {
        anchors.centerIn: parent
        spacing: 30
        width: 360

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 16
            BrandMark { size: 56; anchors.horizontalCenter: parent.horizontalCenter }
            Column {
                spacing: 8
                anchors.horizontalCenter: parent.horizontalCenter
                Wordmark { size: 18; anchors.horizontalCenter: parent.horizontalCenter }
                Txt { text: "Mind maps and moodboards, kept in a vault you own"; variant: "small"; dim: true; anchors.horizontalCenter: parent.horizontalCenter }
            }
        }

        Column {
            width: parent.width
            spacing: 10
            Btn { width: parent.width; kind: "primary"; size: "l"; text: "Create new vault"; icon: "folder-plus"; stretch: true; onClicked: createPicker.open() }
            Btn { width: parent.width; kind: "secondary"; size: "l"; text: "Open existing vault"; icon: "folder-open"; stretch: true; onClicked: openPicker.open() }
            Btn {
                visible: canvas.message.indexOf("could not be found") >= 0
                width: parent.width; kind: "ghost"; size: "m"; text: "Try again"; icon: "arrow-clockwise"; stretch: true
                onClicked: canvas.start()
            }
            Txt {
                width: parent.width
                visible: canvas.message.length > 0
                text: canvas.message
                variant: "small"; color: Theme.warn
                wrapMode: Text.Wrap; horizontalAlignment: Text.AlignHCenter
            }
        }
        Txt {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "v" + app.version; variant: "mono"; muted: true
        }
    }
}
