pragma Singleton
import QtQuick

// Design tokens. One warm-dark palette, one accent (Brotherhood orange): it appears only on the
// primary action, the active pane, the selection ring and new arrivals. Three text tones, all AA
// against `bg`. One radius scale applied everywhere: control 8, card 12, panel 16, pill full.
QtObject {
    // Surfaces (stepped tones; hairlines instead of shadows)
    readonly property color bg: "#0B0B0A"
    readonly property color surface: "#111110"
    readonly property color raised: "#171716"
    readonly property color elevated: "#1D1D1B"
    readonly property color hairline: Qt.rgba(1, 1, 1, 0.07)
    readonly property color hairlineStrong: Qt.rgba(1, 1, 1, 0.14)
    readonly property color scrim: Qt.rgba(0.02, 0.02, 0.02, 0.62)

    // Brand accent. Text on it is `accentInk` (5.6:1); white would only reach 3.5:1.
    readonly property color accent: "#F54F1B"
    readonly property color accentHover: "#FF6234"
    readonly property color accentPressed: "#D9430F"
    readonly property color accentInk: "#0B0B0A"
    readonly property color accentSoft: Qt.rgba(0.961, 0.31, 0.106, 0.14)

    // Text
    readonly property color text: "#ECE8DF"
    readonly property color textDim: "#A19F98"     // secondary
    readonly property color textMuted: "#7C7A74"   // hints, placeholders (4.7:1)

    // Semantic (statuses only)
    readonly property color ok: "#6FB07F"
    readonly property color warn: "#D9905A"
    readonly property color danger: "#D26A5C"
    readonly property color info: "#6B8FB5"

    // Radii
    readonly property int rControl: 8
    readonly property int rCard: 12
    readonly property int rPanel: 16
    readonly property int rPill: 999

    // Spacing
    readonly property int s4: 4
    readonly property int s8: 8
    readonly property int s12: 12
    readonly property int s16: 16
    readonly property int s24: 24
    readonly property int s32: 32

    // Type
    readonly property string sans: "Geist"
    readonly property string mono: "Geist Mono"
    property string brand: ""             // Sequel 100 Black 75, set from Main.qml when the font is bundled
    // Titles (pane, card, section, mode switch, primary buttons): brand face, uppercase, no tracking
    readonly property string headingFamily: brand.length > 0 ? brand : sans
    readonly property int headingWeight: brand.length > 0 ? Font.Normal : Font.Bold

    // Motion. One curve (fast out, soft landing); every duration collapses to 0 under Reduce Motion.
    property bool reduceMotion: false
    readonly property var curve: [0.32, 0.72, 0, 1, 1, 1]
    function ms(base) { return reduceMotion ? 0 : base }
    readonly property int fast: ms(120)
    readonly property int base: ms(220)
    readonly property int slow: ms(460)
    readonly property var curveLayout: [0.22, 1, 0.36, 1, 1, 1]      // ease-out-quint: panes glide, never snap

    // Canvas: note colours and node style presets (user data keeps whatever colour it was saved with)
    readonly property var noteColors: ["#F54F1B", "#E8B547", "#4B8EFF", "#8AE05A", "#E05A5A", "#9B8AE0", "#5AC8E0", "#F0EBE0"]
    readonly property var edgeColors: ["", "#F54F1B", "#E8B547", "#4B8EFF", "#8AE05A", "#E05A5A", "#9B8AE0", "#F0EBE0"]
    readonly property var presets: [
        { label: "Accent", bg: "#1C100C", border: "#F54F1B" },
        { label: "Blue", bg: "#1A1A2E", border: "#4B8EFF" },
        { label: "Green", bg: "#1A2E1A", border: "#8AE05A" },
        { label: "Red", bg: "#2E1A1A", border: "#E05A5A" },
        { label: "Dark", bg: "#0B0B0A", border: "#2A2A28" },
        { label: "Ghost", bg: "transparent", border: "#3A3936" }
    ]

    function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }
}
