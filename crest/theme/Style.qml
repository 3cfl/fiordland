pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

Singleton {
    id: root

    property bool blur: true
    property bool shadows: true
    property bool effects: true

    readonly property real glassAlpha: blur ? 0.72 : 0.94

    readonly property int rNone: 0
    readonly property int rXs: 4
    readonly property int rSm: 8
    readonly property int rMd: 12
    readonly property int rLg: 16
    readonly property int rLgInc: 20
    readonly property int rXl: 28
    readonly property int rXlInc: 32
    readonly property int rXxl: 48
    readonly property int rFull: 1000

    readonly property int s1: 4
    readonly property int s2: 8
    readonly property int s3: 12
    readonly property int s4: 16
    readonly property int s5: 20
    readonly property int s6: 24
    readonly property int s8: 32

    readonly property var families: Qt.fontFamilies()
    readonly property string font: families.indexOf("Inter") >= 0 ? "Inter" : (families.indexOf("Inter Variable") >= 0 ? "Inter Variable" : "sans-serif")
    readonly property string display: families.indexOf("Inter Display") >= 0 ? "Inter Display" : font
    readonly property string mono: "JetBrains Mono"
    readonly property string icons: "Material Symbols Rounded"

    readonly property var type: ({
            displayL: { size: 57, weight: 400, display: true },
            displayM: { size: 45, weight: 400, display: true },
            displayS: { size: 36, weight: 400, display: true },
            headlineL: { size: 32, weight: 500, display: true },
            headlineM: { size: 28, weight: 500, display: true },
            headlineS: { size: 24, weight: 500, display: true },
            titleL: { size: 22, weight: 600, display: false },
            titleM: { size: 16, weight: 600, display: false },
            titleS: { size: 14, weight: 600, display: false },
            bodyL: { size: 16, weight: 400, display: false },
            bodyM: { size: 14, weight: 400, display: false },
            bodyS: { size: 12, weight: 400, display: false },
            labelL: { size: 14, weight: 600, display: false },
            labelM: { size: 12, weight: 600, display: false },
            labelS: { size: 11, weight: 600, display: false }
        })
}
