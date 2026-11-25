pragma ComponentBehavior: Bound

import QtQuick
import qs.theme

Text {
    property string role: "bodyM"
    property bool emphasis: false
    readonly property var spec: Style.type[role] ?? Style.type.bodyM

    color: Colours.fgSurface
    font.family: spec.display ? Style.display : Style.font
    font.pixelSize: spec.size
    font.weight: Math.min(900, spec.weight + (emphasis ? 200 : 0))
    font.letterSpacing: spec.display ? -0.02 * spec.size : 0
    font.features: ({ "tnum": 1 })
    textFormat: Text.PlainText
    elide: Text.ElideRight
    verticalAlignment: Text.AlignVCenter
}
