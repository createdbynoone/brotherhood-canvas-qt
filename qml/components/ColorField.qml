import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Dialogs

// Colour well: a swatch that opens a palette popover, plus a hex field. `color` empty means "default".
Item {
    id: root
    property string value: ""            // "#RRGGBB" or "" for unset
    property string fallback: "#141414"  // shown when unset
    property var swatches: ["#0B0B0A", "#141414", "#1C100C", "#1D1530", "#232A10", "#2A1118", "#F54F1B", "#E8B547", "#8B5CF6", "#B7E43C", "#9B2243", "#9B8AE0", "#5AC8E0", "#F0EBE0", "#6B6A66", "#FFFFFF"]
    property bool allowClear: true
    signal picked(string hex)            // "" clears
    implicitHeight: 30
    implicitWidth: 120

    readonly property string shown: value.length > 0 ? value : fallback
    function normalise(t) {
        let s = t.trim()
        if (s.length === 0) return ""
        if (s[0] !== "#") s = "#" + s
        return /^#[0-9a-fA-F]{6}$/.test(s) ? s.toUpperCase() : null
    }

    Rectangle {
        id: swatch
        width: 30; height: 30; radius: Theme.rControl
        color: root.shown === "transparent" ? "transparent" : root.shown
        border.color: Theme.hairlineStrong
        Rectangle {   // a slash marks "no fill"
            visible: root.shown === "transparent"
            anchors.centerIn: parent; width: 1.5; height: 24; rotation: 45; color: Theme.textMuted
        }
        TapHandler { onTapped: pop.opened ? pop.close() : pop.open() }
        HoverHandler { cursorShape: Qt.PointingHandCursor }
    }
    Field {
        x: 38; width: parent.width - 38
        mono: true
        text: root.value
        placeholder: root.fallback === "transparent" ? "none" : root.fallback.toUpperCase()
        implicitHeight: 30
        onAccepted: { const n = root.normalise(text); if (n !== null) root.picked(n); else text = root.value }
        inputItem.onActiveFocusChanged: if (!inputItem.activeFocus) { const n = root.normalise(text); if (n !== null && n !== root.value) root.picked(n); else text = root.value }
    }

    ColorDialog { id: dialog; selectedColor: root.shown; onAccepted: root.picked(selectedColor.toString().toUpperCase().slice(0, 7)) }

    Popup {
        id: pop
        y: swatch.height + 6
        padding: 10
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent
        background: Rectangle { radius: Theme.rCard; color: Theme.elevated; border.color: Theme.hairlineStrong }
        contentItem: Column {
            spacing: 8
            Grid {
                columns: 8; spacing: 6
                Repeater {
                    model: root.swatches
                    delegate: Rectangle {
                        required property string modelData
                        width: 22; height: 22; radius: 6
                        color: modelData
                        border.color: modelData.toUpperCase() === root.value.toUpperCase() ? Theme.accent : Theme.hairlineStrong
                        border.width: modelData.toUpperCase() === root.value.toUpperCase() ? 2 : 1
                        TapHandler { onTapped: { root.picked(modelData); pop.close() } }
                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                    }
                }
            }
            Row {
                spacing: 6
                Btn { kind: "secondary"; size: "xs"; text: "More colors"; icon: "palette"; onClicked: { pop.close(); dialog.open() } }
                Btn { visible: root.allowClear; kind: "ghost"; size: "xs"; text: "Default"; onClicked: { root.picked(""); pop.close() } }
            }
        }
    }
}
