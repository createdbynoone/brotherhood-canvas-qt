import QtQuick

// The one button. kind: primary | secondary | ghost | destructive. size: xs 24, s 28, m 32, l 40.
// Hover / pressed state is local to each button.
Item {
    id: root
    property string kind: "secondary"
    property string size: "s"
    property string text: ""
    property string icon: ""
    property string iconWeight: "regular"
    property string tip: ""
    property string hint: ""            // shortcut shown in the tooltip
    property bool busy: false
    property bool iconOnly: text.length === 0
    property color tint: "transparent"  // overrides the primary fill (fire button states)
    property bool stretch: false        // fill the parent's width
    readonly property bool hovered: hover.hovered
    readonly property bool pressed: tap.pressed
    signal clicked()

    readonly property int h: size === "xs" ? 24 : size === "s" ? 28 : size === "m" ? 32 : 40
    readonly property int fontSize: size === "xs" ? 11 : size === "s" ? 12 : 13
    readonly property int pad: size === "xs" ? 8 : size === "s" ? 10 : size === "m" ? 12 : 16
    readonly property bool headingText: kind === "primary" && size === "l"
    readonly property int iconSize: size === "l" ? 16 : size === "xs" ? 13 : 14

    implicitHeight: h
    implicitWidth: stretch && parent ? parent.width : (iconOnly ? h : row.implicitWidth + pad * 2)
    opacity: enabled || kind === "primary" ? 1 : 0.4
    activeFocusOnTab: true
    scale: pressed ? 0.98 : 1
    Behavior on scale { NumberAnimation { duration: Theme.fast; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: Theme.fast } }

    readonly property color fillColor: {
        switch (kind) {
        case "primary": return !enabled ? Theme.raised : tint.a > 0 ? tint : (pressed ? Theme.accentPressed : hovered ? Theme.accentHover : Theme.accent)
        case "secondary": return hovered ? Theme.elevated : Theme.raised
        case "destructive": return Theme.alpha(Theme.danger, hovered ? 0.22 : 0.14)
        default: return pressed || hovered ? Qt.rgba(1, 1, 1, 0.06) : "transparent"
        }
    }
    readonly property color inkColor: {
        switch (kind) {
        case "primary": return enabled ? Theme.accentInk : Theme.textMuted
        case "destructive": return Theme.danger
        case "secondary": return Theme.text
        default: return hovered ? Theme.text : Theme.textDim
        }
    }
    readonly property color strokeColor: kind === "primary" && !enabled ? Theme.hairline : kind === "secondary" ? (hovered ? Theme.hairlineStrong : Theme.hairline)
        : kind === "destructive" ? Theme.alpha(Theme.danger, 0.4) : "transparent"

    Rectangle {
        anchors.fill: parent
        radius: Theme.rControl
        color: root.fillColor
        border.color: root.strokeColor
        Behavior on color { ColorAnimation { duration: Theme.fast } }
    }
    Rectangle {   // keyboard focus ring
        anchors.fill: parent
        anchors.margins: -2
        radius: Theme.rControl + 2
        color: "transparent"
        border.color: Theme.accent
        border.width: 2
        visible: root.activeFocus && root.focusReason === Qt.TabFocusReason
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6
        Icon {
            visible: root.icon.length > 0 && !root.busy
            name: root.icon; weight: root.iconWeight; size: root.iconSize; color: root.inkColor
            anchors.verticalCenter: parent.verticalCenter
        }
        Item {
            visible: root.busy
            width: 8; height: 8
            anchors.verticalCenter: parent.verticalCenter
            Pulse { anchors.centerIn: parent; dotColor: root.inkColor; running: root.busy }
        }
        Txt {
            visible: root.text.length > 0
            text: root.text
            font.pixelSize: root.headingText ? 12 : root.fontSize
            font.family: root.headingText ? Theme.headingFamily : Theme.sans
            font.weight: root.headingText ? Theme.headingWeight : root.kind === "primary" ? Font.DemiBold : Font.Medium
            font.capitalization: root.headingText ? Font.AllUppercase : Font.MixedCase
            font.letterSpacing: 0
            color: root.inkColor
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
    TapHandler { id: tap; enabled: root.enabled; gesturePolicy: TapHandler.ReleaseWithinBounds; onTapped: root.clicked() }
    Keys.onSpacePressed: if (enabled) clicked()
    Keys.onReturnPressed: if (enabled) clicked()

    Tip { target: root; text: root.tip; hint: root.hint }
}
