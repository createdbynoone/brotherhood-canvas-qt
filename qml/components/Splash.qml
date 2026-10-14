import QtQuick

// A beat on launch: the mark fades in and settles, then hands off to the lock / main view.
Rectangle {
    id: root
    color: Theme.bg
    signal finished()
    property bool shown: false

    BrandMark {
        anchors.centerIn: parent
        size: 72
        opacity: root.shown ? 1 : 0
        scale: root.shown ? 1 : 0.96
        Behavior on opacity { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
    }
    Component.onCompleted: shown = true
    Timer { interval: Theme.reduceMotion ? 60 : 1100; running: true; onTriggered: { root.shown = false; done.start() } }
    Timer { id: done; interval: Theme.reduceMotion ? 0 : 260; onTriggered: root.finished() }
}
