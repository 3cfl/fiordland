import QtQuick
import qs.components

Item {
    id: root

    implicitWidth: 112
    implicitHeight: 112

    Logo {
        id: img

        anchors.centerIn: parent
        width: root.width
        height: root.height
        opacity: 0
        scale: 0.7

        Component.onCompleted: intro.start()

        ParallelAnimation {
            id: intro

            NumberAnimation {
                target: img
                property: "opacity"
                to: 1
                duration: 500
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: img
                property: "scale"
                to: 1
                duration: 700
                easing.type: Easing.OutBack
            }
        }
    }
}
