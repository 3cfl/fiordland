import QtQuick
import QtQuick.Effects
import qs.theme

Item {
    id: root

    property string source
    property string shape: "cookie9"
    property string initial
    readonly property bool hasImage: img.status === Image.Ready

    implicitWidth: 96
    implicitHeight: 96

    ExprShape {
        anchors.fill: parent
        shape: root.shape
        color: Colours.primaryContainer
        visible: !root.hasImage
    }

    Txt {
        anchors.centerIn: parent
        visible: !root.hasImage && root.initial !== ""
        text: root.initial.charAt(0).toUpperCase()
        role: "displayS"
        font.pixelSize: root.height * 0.42
        color: Colours.onPrimaryContainer
    }

    Icon {
        anchors.centerIn: parent
        visible: !root.hasImage && root.initial === ""
        name: "person"
        fill: 1
        size: root.height * 0.5
        color: Colours.onPrimaryContainer
    }

    Image {
        id: img

        anchors.fill: parent
        source: root.source
        sourceSize.width: width * 2
        sourceSize.height: height * 2
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        visible: false
    }

    ExprShape {
        id: mask

        anchors.fill: parent
        shape: root.shape
        color: "white"
        visible: false
        layer.enabled: true
        layer.samples: 4
    }

    MultiEffect {
        anchors.fill: parent
        visible: root.hasImage
        source: img
        maskEnabled: true
        maskSource: mask
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1
    }
}
