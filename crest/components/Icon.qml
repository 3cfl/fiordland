pragma ComponentBehavior: Bound

import QtQuick
import qs.theme

Text {
    id: root

    property string name
    property real fill: 0
    property int size: 22
    property int weight: 400

    text: name
    color: Colours.fgSurface
    textFormat: Text.PlainText
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    font.family: Style.icons
    font.pixelSize: size
    font.hintingPreference: Font.PreferNoHinting
    renderType: Text.CurveRendering
    font.variableAxes: ({ "FILL": root.fill, "wght": root.weight, "GRAD": 0, "opsz": Math.max(20, Math.min(48, root.size)) })
}
