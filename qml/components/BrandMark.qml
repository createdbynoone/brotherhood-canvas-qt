import QtQuick

// Brotherhood isotype. Pre-coloured SVGs rendered at the screen's pixel density, so it stays sharp.
Item {
    id: root
    property int size: 24
    property color tint: Theme.text
    readonly property bool muted: !Qt.colorEqual(tint, Theme.text)
    width: size; height: size
    Image {
        anchors.fill: parent
        source: root.muted ? "qrc:/assets/images/logo-muted.svg" : "qrc:/assets/images/logo-text.svg"
        sourceSize: Qt.size(Math.ceil(root.size * Screen.devicePixelRatio * 2), Math.ceil(root.size * Screen.devicePixelRatio * 2))
        fillMode: Image.PreserveAspectFit
        mipmap: true
        smooth: true
        asynchronous: false
    }
}
