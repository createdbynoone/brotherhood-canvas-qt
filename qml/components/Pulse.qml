import QtQuick

// "Something is running" dot. Deliberately not a continuous animation: a slow timer flips the opacity
// and a short fade softens the change, so an idle-but-busy window renders ~3 frames per second
// instead of 60 (the SwiftUI builds hit ~45 % CPU with a repeatForever animation).
Rectangle {
    id: root
    property color dotColor: Theme.accent
    property bool running: true
    property bool low: false

    width: 6; height: 6; radius: 3
    color: dotColor
    opacity: low ? 0.3 : 1
    Behavior on opacity { NumberAnimation { duration: 320; easing.type: Easing.InOutSine } }
    Timer {
        interval: 800; repeat: true
        running: root.running && root.visible && !Theme.reduceMotion
        onTriggered: root.low = !root.low
    }
}
