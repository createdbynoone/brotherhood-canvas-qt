import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Dialogs
import QtCore

// Export the whole board or the selection as a PNG or a vector PDF.
Popup {
    id: root
    property string format: "png"
    property bool selectionOnly: false
    readonly property bool hasSelection: board.selectedCount > 0

    parent: Overlay.overlay
    anchors.centerIn: Overlay.overlay
    modal: true
    width: 420
    padding: 22
    closePolicy: Popup.CloseOnEscape
    Overlay.modal: Rectangle { color: Theme.scrim }
    background: Rectangle { radius: Theme.rPanel; color: Theme.surface; border.color: Theme.hairlineStrong }
    onAboutToShow: selectionOnly = hasSelection

    FileDialog {
        id: save
        title: "Export board"
        fileMode: FileDialog.SaveFile
        defaultSuffix: root.format
        nameFilters: root.format === "pdf" ? ["PDF (*.pdf)"] : root.format === "jpg" ? ["JPEG (*.jpg)"] : ["PNG (*.png)"]
        currentFile: app.fileUrl(StandardPaths.writableLocation(StandardPaths.DesktopLocation) + "/" + board.boardName + "." + root.format)
        onAccepted: { canvas.exportBoard(selectedFile, root.selectionOnly); root.close() }
    }

    contentItem: Column {
        spacing: 16
        Row {
            width: parent.width; spacing: 10
            Icon { name: "export"; size: 18; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
            Txt { text: "Export"; variant: "title"; anchors.verticalCenter: parent.verticalCenter }
        }
        Column {
            width: parent.width; spacing: 8
            Txt { text: "What"; variant: "label"; muted: true }
            Segment {
                options: [{ key: false, label: "Whole board" }, { key: true, label: "Selection" + (root.hasSelection ? " (" + board.selectedCount + ")" : "") }]
                current: root.selectionOnly
                onPicked: key => { if (key === false || root.hasSelection) root.selectionOnly = key }
                height_: 32
            }
        }
        Column {
            width: parent.width; spacing: 8
            Txt { text: "Format"; variant: "label"; muted: true }
            Segment {
                options: [{ key: "png", label: "PNG" }, { key: "jpg", label: "JPEG" }, { key: "pdf", label: "PDF (vector)" }]
                current: root.format
                onPicked: key => root.format = key
                height_: 32
            }
            Txt {
                width: parent.width; wrapMode: Text.Wrap; variant: "small"; muted: true
                text: root.format === "pdf" ? "One page the size of the content, text stays sharp at any zoom." : "Up to 2x resolution, capped at 6144 px on the long side."
            }
        }
        Row {
            anchors.right: parent.right; spacing: 8
            Btn { kind: "secondary"; size: "m"; text: "Cancel"; onClicked: root.close() }
            Btn { kind: "primary"; size: "m"; text: "Export"; onClicked: save.open() }
        }
    }
}
