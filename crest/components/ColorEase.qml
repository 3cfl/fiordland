pragma ComponentBehavior: Bound

import QtQuick
import qs.theme

ColorAnimation {
    duration: Motion.durShort
    easing.type: Easing.BezierSpline
    easing.bezierCurve: Motion.standard
}
