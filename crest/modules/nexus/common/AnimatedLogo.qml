import QtQuick
import Quickshell
import qs.components

Item {
    id: root

    implicitWidth: 112
    implicitHeight: 112

    Image {
        id: img

        anchors.centerIn: parent
        width: root.width
        height: root.height
        source: Qt.resolvedUrl(`${Quickshell.shellDir}/assets/logo.svg`)
        sourceSize: Qt.size(width * 2, height * 2)
        fillMode: Image.PreserveAspectFit
        smooth: true
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
