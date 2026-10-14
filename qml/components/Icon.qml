import QtQuick

// Phosphor glyph. `weight`: regular | bold | fill
Text {
    property string name: ""
    property string weight: "regular"
    property int size: 16

    text: Icons.glyph(name)
    font.family: weight === "fill" ? "Phosphor-Fill" : weight === "bold" ? "Phosphor-Bold" : "Phosphor"
    font.pixelSize: size
    color: Theme.text
    width: size
    height: size
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    renderType: Text.NativeRendering
}
