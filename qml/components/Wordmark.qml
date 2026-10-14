import QtQuick

// BROTHERHOOD® in the brand face (Sequel 100 Black 75, caps), followed by "Canvas" in the UI face.
Row {
    id: root
    property int size: 13
    property bool showStudio: true
    spacing: Math.round(size * 0.5)

    Row {
        spacing: Math.max(1, Math.round(size * 0.12))
        anchors.verticalCenter: parent.verticalCenter
        Text {
            id: word
            text: "BROTHERHOOD"
            color: Theme.text
            font.family: Theme.brand.length > 0 ? Theme.brand : Theme.sans
            font.weight: Theme.brand.length > 0 ? Font.Normal : Font.Bold
            font.pixelSize: root.size
            font.letterSpacing: root.size * 0.06
            renderType: Text.NativeRendering
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {   // registered mark: a superscript, drawn in the UI face so the glyph is always present
            text: "\u00AE"
            color: Theme.textDim
            font.family: Theme.sans
            font.pixelSize: Math.max(8, Math.round(root.size * 0.66))
            renderType: Text.NativeRendering
            anchors.top: word.top
            anchors.topMargin: -Math.round(root.size * 0.12)
        }
    }
    Txt {
        visible: root.showStudio
        text: "Canvas"
        font.pixelSize: Math.round(root.size * 1.08)
        dim: true
        anchors.verticalCenter: parent.verticalCenter
    }
}
