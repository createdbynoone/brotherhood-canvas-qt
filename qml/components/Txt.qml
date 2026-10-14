import QtQuick

// The only text element: a fixed type scale. Hierarchy comes from weight and tone, not size.
Text {
    // display 20/600, title 15/600, body 13/400, strong 13/500, small 12/400, label 11/500, caption 11/400, mono 11/500,
    // heading 12 and overline 11: brand face, uppercase, no tracking
    property string variant: "body"
    property bool dim: false
    property bool muted: false

    readonly property var spec: ({
        display: { size: 20, weight: Font.DemiBold, spacing: -0.3 },
        title: { size: 15, weight: Font.DemiBold, spacing: -0.1 },
        body: { size: 13, weight: Font.Normal, spacing: 0 },
        strong: { size: 13, weight: Font.Medium, spacing: 0 },
        small: { size: 12, weight: Font.Normal, spacing: 0 },
        label: { size: 11, weight: Font.Medium, spacing: 0.1 },
        caption: { size: 11, weight: Font.Normal, spacing: 0 },
        heading: { size: 12, weight: Font.Normal, spacing: 0 },
        overline: { size: 11, weight: Font.Normal, spacing: 0 },
        mono: { size: 11, weight: Font.Medium, spacing: 0 }
    })
    readonly property var s: spec[variant] || spec.body

    readonly property bool isHeading: variant === "heading" || variant === "overline"
    font.family: variant === "mono" ? Theme.mono : isHeading ? Theme.headingFamily : Theme.sans
    font.pixelSize: s.size
    font.weight: isHeading ? Theme.headingWeight : s.weight
    font.letterSpacing: s.spacing
    font.capitalization: isHeading ? Font.AllUppercase : Font.MixedCase
    color: muted ? Theme.textMuted : dim ? Theme.textDim : Theme.text
    renderType: Text.NativeRendering
    elide: Text.ElideNone
    wrapMode: Text.NoWrap
}
