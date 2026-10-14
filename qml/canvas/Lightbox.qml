import QtQuick
import QtMultimedia

// Full-size viewer for an image or video node. Esc closes; images zoom with the wheel and pan by dragging.
Item {
    id: root
    property bool open: false
    property var info: ({})
    readonly property bool isVideo: info.type === "video"

    visible: opacity > 0.01
    opacity: open ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: Theme.base } }

    function show(id) {
        info = board.nodeInfo(id)
        pic.scale = 1; pic.x = 0; pic.y = 0
        open = true
        keys.forceActiveFocus()
    }
    function hide() { open = false; player.stop(); Cam.focusRequested() }

    Rectangle { anchors.fill: parent; color: Qt.rgba(0.02, 0.02, 0.02, 0.94); MouseArea { anchors.fill: parent; onClicked: root.hide(); onWheel: w => w.accepted = true } }

    FocusScope {
        id: keys
        anchors.fill: parent
        Keys.onEscapePressed: root.hide()
        Keys.onSpacePressed: if (root.isVideo) { player.playbackState === MediaPlayer.PlayingState ? player.pause() : player.play() }
    }

    // Image
    Item {
        id: stage
        visible: !root.isVideo
        anchors.fill: parent; anchors.topMargin: 64; anchors.bottomMargin: 32; anchors.leftMargin: 48; anchors.rightMargin: 48
        clip: true
        Image {
            id: pic
            width: stage.width; height: stage.height
            fillMode: Image.PreserveAspectFit
            asynchronous: true; mipmap: true; smooth: true
            source: root.open && !root.isVideo && root.info.filePath ? "image://media/" + encodeURIComponent(root.info.filePath) + "?s=4096" : ""
            transformOrigin: Item.Center
            Behavior on scale { enabled: !wheel.active; NumberAnimation { duration: Theme.fast } }
        }
        MouseArea {
            id: wheel
            property bool active: false
            anchors.fill: parent
            drag.target: pic; drag.axis: Drag.XAndYAxis
            onWheel: w => { active = true; pic.scale = Math.max(0.5, Math.min(8, pic.scale * Math.exp(w.angleDelta.y * 0.0012 + w.pixelDelta.y * 0.006))); active = false }
            onDoubleClicked: { pic.scale = pic.scale > 1.05 ? 1 : 2.5; pic.x = 0; pic.y = 0 }
        }
    }

    // Video
    MediaPlayer {
        id: player
        source: root.open && root.isVideo && root.info.filePath ? app.fileUrl(board.filePathOf(root.info.id)) : ""
        videoOutput: vo
        audioOutput: AudioOutput { id: audio; volume: app.volume; muted: false }
        onSourceChanged: if (source.toString().length > 0) play()
    }
    VideoOutput {
        id: vo
        visible: root.isVideo
        anchors.fill: parent; anchors.topMargin: 64; anchors.bottomMargin: 96; anchors.leftMargin: 48; anchors.rightMargin: 48
        fillMode: VideoOutput.PreserveAspectFit
        TapHandler { onTapped: player.playbackState === MediaPlayer.PlayingState ? player.pause() : player.play() }
    }
    Rectangle {
        visible: root.isVideo
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom; anchors.bottomMargin: 28
        width: Math.min(560, parent.width - 96); height: 48
        radius: Theme.rPanel; color: Theme.alpha(Theme.surface, 0.96); border.color: Theme.hairlineStrong
        Row {
            anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 14
            spacing: 10
            Btn { anchors.verticalCenter: parent.verticalCenter; kind: "ghost"; size: "m"; icon: player.playbackState === MediaPlayer.PlayingState ? "pause" : "play"; iconWeight: "fill"; onClicked: player.playbackState === MediaPlayer.PlayingState ? player.pause() : player.play() }
            Txt { anchors.verticalCenter: parent.verticalCenter; text: root.fmt(player.position); variant: "mono"; dim: true; width: 40 }
            Slide {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 40 - 40 - 32 - 110 - 40
                from: 0; to: Math.max(1, player.duration); value: player.position; active: true; readout: false
                onMoved: v => player.position = v
                // the built-in readout is replaced by the labels on both sides
            }
            Txt { anchors.verticalCenter: parent.verticalCenter; text: root.fmt(player.duration); variant: "mono"; dim: true; width: 40 }
            Icon { anchors.verticalCenter: parent.verticalCenter; name: app.volume > 0 ? "speaker-high" : "speaker-slash"; size: 16; color: Theme.textDim }
            Slide { anchors.verticalCenter: parent.verticalCenter; width: 90; from: 0; to: 1; value: app.volume; active: true; readout: false; onMoved: v => app.volume = v }
        }
    }
    function fmt(ms) { const s = Math.floor(ms / 1000); return Math.floor(s / 60) + ":" + ("0" + (s % 60)).slice(-2) }

    // Header
    Item {
        anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
        height: 56
        Txt {
            anchors.left: parent.left; anchors.leftMargin: 24; anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 320
            text: root.info.fileName ? root.info.fileName : ""
            variant: "mono"; dim: true; elide: Text.ElideMiddle
        }
        Row {
            anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            Btn { kind: "secondary"; size: "s"; icon: "folder-open"; text: "Show in Finder"; onClicked: canvas.revealNode(root.info.id) }
            Btn { kind: "secondary"; size: "s"; icon: "arrow-square-out"; text: "Open"; onClicked: canvas.openNodeFile(root.info.id) }
            Btn { kind: "ghost"; size: "s"; icon: "x"; tip: "Close"; hint: "Esc"; onClicked: root.hide() }
        }
    }
    MouseArea { anchors.fill: parent; z: -2; acceptedButtons: Qt.NoButton; hoverEnabled: false }
}
