pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

Singleton {
    property bool reduced: false

    readonly property int durShort: reduced ? 1 : 150
    readonly property int durMedium: reduced ? 1 : 300
    readonly property int durLong: reduced ? 1 : 500
    readonly property int durExtraLong: reduced ? 1 : 700

    readonly property list<real> emphasizedDecel: [0.05, 0.7, 0.1, 1, 1, 1]
    readonly property list<real> emphasizedAccel: [0.3, 0, 0.8, 0.15, 1, 1]
    readonly property list<real> standard: [0.2, 0, 0, 1, 1, 1]
    readonly property list<real> overshoot: [0.34, 1.4, 0.64, 1, 1, 1]

    readonly property real fastSpring: reduced ? 40 : 5
    readonly property real fastDamping: reduced ? 1 : 0.28
    readonly property real defaultSpring: reduced ? 40 : 3.5
    readonly property real defaultDamping: reduced ? 1 : 0.35
    readonly property real slowSpring: reduced ? 40 : 2.4
    readonly property real slowDamping: reduced ? 1 : 0.4
}
