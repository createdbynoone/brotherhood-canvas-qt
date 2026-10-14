import QtQuick

// PDF or any other file: the first page of a PDF (or a file glyph) above a name and size footer.
Item {
    id: root
    property Item node
    readonly property bool isPdf: node.nodeType === "pdf"
    readonly property real footer: 46

    Rectangle {
        x: 0; y: 0; width: parent.width; height: parent.height - root.footer
        color: Theme.raised
        visible: !isPdf || page.status !== Image.Ready
    }
    RoundedImage {
        id: page
        x: 0; y: 0; width: parent.width; height: parent.height - root.footer
        visible: root.isPdf
        radius: 0
        aa: 1 / Cam.zoomQ
        source: root.isPdf && node.filePath.length > 0 ? "image://media/" + encodeURIComponent(node.filePath) + "?s=" + (node.width * Cam.zoomQ * Screen.devicePixelRatio > 600 ? 1024 : 512) : ""
    }
    Icon {
        visible: !root.isPdf || page.status === Image.Error
        anchors.horizontalCenter: parent.horizontalCenter
        y: (parent.height - root.footer) / 2 - height / 2
        name: root.isPdf ? "file-pdf" : "file"; size: 40; color: Theme.textMuted
    }
    Rectangle { x: 0; y: parent.height - root.footer; width: parent.width; height: 1 / Cam.zoomQ; color: Theme.hairline }
    Column {
        x: 12; y: parent.height - root.footer + 8
        width: parent.width - 24
        spacing: 2
        Txt { width: parent.width; text: node.fileName; variant: "strong"; font.pixelSize: 12; elide: Text.ElideMiddle; renderType: Text.QtRendering }
        Txt { text: (root.isPdf ? "PDF · " : "") + app.formatSize(node.fileSize); variant: "caption"; muted: true; renderType: Text.QtRendering }
    }
}
