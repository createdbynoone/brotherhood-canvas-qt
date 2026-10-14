import QtQuick
import QtQuick.Controls.Basic

// Tooltip that matches the app. Attach with `Tip { target: someItem; text: "..." }`.
Popup {
    id: root
    property Item target
    property string text: ""
    property string hint: ""          // keyboard shortcut shown on the right
    property bool shown: false

    parent: target
    visible: shown && text.length > 0
    x: target ? Math.round((target.width - width) / 2) : 0
    y: target ? target.height + 8 : 0
    padding: 0
    modal: false
    focus: false
    closePolicy: Popup.NoAutoClose
    enter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.fast } }

    Timer { id: delay; interval: 450; onTriggered: root.shown = hover.hovered }
    HoverHandler {
        id: hover
        target: root.target
        onHoveredChanged: { if (hovered) delay.restart(); else { delay.stop(); root.shown = false } }
    }

    background: Rectangle {
        radius: Theme.rControl
        color: Theme.elevated
        border.color: Theme.hairlineStrong
    }
    contentItem: Row {
        spacing: 10
        leftPadding: 10; rightPadding: 10; topPadding: 6; bottomPadding: 6
        Txt { text: root.text; variant: "small"; anchors.verticalCenter: parent.verticalCenter }
        Txt { visible: root.hint.length > 0; text: root.hint; variant: "mono"; muted: true; anchors.verticalCenter: parent.verticalCenter }
    }
}
