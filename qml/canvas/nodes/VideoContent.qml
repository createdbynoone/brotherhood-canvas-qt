import QtQuick
import QtMultimedia

// Poster frame until it is played; one click plays or pauses, double click opens the viewer.
Item {
    id: root
    property Item node
    readonly property bool playing: Cam.playingId === node.nodeId
    function primaryAction() { Cam.playingId = playing ? "" : node.nodeId }

    readonly property real dpr: Screen.devicePixelRatio
    readonly property int need: {
        const px = Math.max(node.width, node.height) * Cam.zoomQ * dpr
        let s = 256
        while (s < px && s < 2048) s *= 2
        return s
    }
    property int bucket: need
    onNeedChanged: if (need > bucket || need * 4 <= bucket) settle.restart()
    Timer { id: settle; interval: 160; onTriggered: root.bucket = root.need }

    readonly property string posterRel: node.thumbPath.length > 0 ? node.thumbPath : node.filePath

    RoundedImage {
        anchors.fill: parent
        radius: node.radiusPx
        aa: 1 / Cam.zoomQ
        visible: !player.active
        dim: 0.12
        source: root.posterRel.length > 0 ? "image://media/" + encodeURIComponent(root.posterRel) + "?s=" + root.bucket : ""
    }

    Loader {
        id: player
        anchors.fill: parent
        active: root.playing
        sourceComponent: Item {
            MediaPlayer {
                id: mp
                source: app.fileUrl(node.fileAbs)
                videoOutput: vo
                audioOutput: AudioOutput { volume: app.volume }
                loops: MediaPlayer.Infinite
                Component.onCompleted: play()
            }
            // The frames are cropped to the node by the VideoOutput, then rounded by the same shader as the posters
            VideoOutput { id: vo; anchors.fill: parent; fillMode: VideoOutput.PreserveAspectCrop }
            ShaderEffectSource {
                id: tex
                anchors.fill: parent
                sourceItem: vo
                hideSource: true
                live: true
                visible: false
                textureSize: Qt.size(Math.min(2048, Math.max(64, width * Cam.zoomQ * root.dpr)), Math.min(2048, Math.max(64, height * Cam.zoomQ * root.dpr)))
            }
            RoundedImage {
                anchors.fill: parent
                radius: node.radiusPx
                aa: 1 / Cam.zoomQ
                cover: false
                external: tex
            }
            Rectangle {   // progress hairline
                anchors.left: parent.left; anchors.bottom: parent.bottom
                height: 3 / Cam.zoomQ
                width: mp.duration > 0 ? parent.width * mp.position / mp.duration : 0
                color: Theme.accent
            }
        }
    }

    Rectangle {   // play marker
        visible: !root.playing
        anchors.centerIn: parent
        width: Math.max(18, Math.min(46, Math.min(root.width, root.height) * 0.3)); height: width; radius: width / 2
        color: Theme.alpha(Theme.bg, 0.62)
        border.color: Theme.alpha(Theme.text, 0.25); border.width: 1 / Cam.zoomQ
        Icon { anchors.centerIn: parent; anchors.horizontalCenterOffset: 1; name: "play"; weight: "fill"; size: parent.width * 0.42; color: Theme.text }
    }
}
