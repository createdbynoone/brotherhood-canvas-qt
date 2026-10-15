import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Window

ApplicationWindow {
    id: win
    visible: true
    readonly property var gs: (typeof grabSize === "string" && grabSize.indexOf("x") > 0) ? grabSize.split("x").map(Number) : [1480, 900]
    // Last window position and size, if it still lands on a screen; otherwise a default that fits the display
    readonly property var saved: {
        if (sizeForced) return []
        const g = app.windowGeometry()
        if (g.length !== 4 || g[2] < 720 || g[3] < 480) return []
        // Qt 6.12 screen objects expose virtualX/virtualY/width/height, no longer a virtualGeometry rect
        for (const s of Qt.application.screens) {
            if (g[0] + 120 > s.virtualX && g[0] + 120 < s.virtualX + s.width && g[1] >= s.virtualY - 4 && g[1] < s.virtualY + s.height - 80) return g
        }
        return []
    }
    width: saved.length ? saved[2] : Math.min(gs[0], Screen.desktopAvailableWidth * 0.94)
    height: saved.length ? saved[3] : Math.min(gs[1], Screen.desktopAvailableHeight * 0.94)
    x: saved.length ? saved[0] : Math.round((Screen.desktopAvailableWidth - width) / 2)
    y: saved.length ? saved[1] : Math.round((Screen.desktopAvailableHeight - height) / 2)
    Timer {
        id: rememberWindow
        interval: 500
        onTriggered: if (win.visibility === Window.Windowed && !sizeForced) app.saveWindowGeometry(win.x, win.y, win.width, win.height)
    }
    onXChanged: rememberWindow.restart()
    onYChanged: rememberWindow.restart()
    onWidthChanged: rememberWindow.restart()
    onHeightChanged: rememberWindow.restart()
    minimumWidth: 720
    minimumHeight: 480
    color: Theme.bg
    title: canvas.state === "ready" ? board.boardName + " · Brotherhood Canvas" : "Brotherhood Canvas"

    property bool splashDone: false

    // Native title-bar drag (Mac.installTitleBarDrag): which points are empty space?
    function titleBarHit(x, y) {
        if (!splashDone || !app.unlocked || canvas.state !== "ready") return y < 92
        return workspace.item ? workspace.item.dragAt(x, y) : false
    }
    Component.onCompleted: { Theme.reduceMotion = app.reduceMotion; Theme.brand = brandFamily; Theme.marker = markerFamily }

    Loader {
        id: workspace
        anchors.fill: parent
        active: win.splashDone && app.unlocked && canvas.state === "ready"
        sourceComponent: Workspace {}
        opacity: active ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.slow } }
    }
    Welcome {
        anchors.fill: parent
        visible: win.splashDone && app.unlocked && canvas.state === "welcome"
    }
    LockScreen {
        anchors.fill: parent
        visible: win.splashDone && !app.unlocked
    }
    Splash {
        anchors.fill: parent
        visible: !win.splashDone
        onFinished: win.splashDone = true
    }
}
