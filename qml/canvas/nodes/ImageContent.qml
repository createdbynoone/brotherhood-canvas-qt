import QtQuick

Item {
    id: root
    property Item node

    // Decode at roughly the size it is shown (power of two), refined after the camera settles
    readonly property real dpr: Screen.devicePixelRatio
    readonly property int need: {
        const px = Math.max(node.width, node.height) * Cam.zoomQ * dpr
        let s = 256
        while (s < px && s < 4096) s *= 2
        return s
    }
    property int bucket: need
    onNeedChanged: if (need > bucket || need * 4 <= bucket) settle.restart()
    Timer { id: settle; interval: 160; onTriggered: root.bucket = root.need }

    RoundedImage {
        id: pic
        anchors.fill: parent
        radius: node.radiusPx
        aa: 1 / Cam.zoomQ
        source: node.filePath.length > 0 ? "image://media/" + encodeURIComponent(node.filePath) + "?s=" + root.bucket : ""
    }
    Column {
        visible: pic.status === Image.Error || node.filePath.length === 0
        anchors.centerIn: parent
        spacing: 6
        Icon { anchors.horizontalCenter: parent.horizontalCenter; name: "image"; size: 26; color: Theme.textMuted }
        Txt { anchors.horizontalCenter: parent.horizontalCenter; text: node.fileName; variant: "caption"; muted: true; renderType: Text.QtRendering }
    }
}
