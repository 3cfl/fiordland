pragma ComponentBehavior: Bound

import QtQuick
import qs.theme

NumberAnimation {
    duration: Motion.durMedium
    easing.type: Easing.BezierSpline
    easing.bezierCurve: Motion.emphasizedDecel
}
