pragma ComponentBehavior: Bound

import QtQuick
import qs.theme

Item {
    id: root

    property color color: Colours.primary
    property bool running: visible
    property int step: 0
    readonly property var sequence: ["softburst", "cookie9", "puffy", "sunny", "cookie4", "flower", "clover4"]

    implicitWidth: 48
    implicitHeight: 48

    ExprShape {
        id: shape

        anchors.centerIn: parent
        width: parent.width * 0.79
        height: width
        color: root.color
        shape: root.sequence[root.step % root.sequence.length]
        segments: 96

        RotationAnimator on rotation {
            running: root.running && !Motion.reduced
            from: 0
            to: 360
            duration: 4600
            loops: Animation.Infinite
        }
    }

    Timer {
        interval: 650
        repeat: true
        running: root.running && !Motion.reduced
        onTriggered: root.step++
    }
}
