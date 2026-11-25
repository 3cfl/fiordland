pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.theme

PanelWindow {
    id: win

    required property ShellScreen modelData
    property string shown: ""

    screen: modelData
    color: Colours.surfaceContainerLowest
    WlrLayershell.namespace: "crest-background"
    WlrLayershell.layer: WlrLayer.Background
    exclusionMode: ExclusionMode.Ignore
    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true

    readonly property string target: Wallpapers.current
    onTargetChanged: swap()
    Component.onCompleted: swap()

    function swap(): void {
        const next = a.opacity > 0.5 ? b : a;
        next.source = target;
    }

    Wall {
        id: a
    }

    Wall {
        id: b
    }

    component Wall: Image {
        id: img

        anchors.fill: parent
        sourceSize.width: win.width
        sourceSize.height: win.height
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        opacity: 0

        onStatusChanged: {
            if (status !== Image.Ready)
                return;
            const other = img === a ? b : a;
            img.z = 1;
            other.z = 0;
            fadeIn.target = img;
            fadeIn.other = other;
            fadeIn.restart();
        }
    }

    NumberAnimation {
        id: fadeIn

        property Image other: null

        property: "opacity"
        to: 1
        duration: Motion.durExtraLong
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Motion.standard
        onFinished: {
            if (other && other !== target) {
                other.opacity = 0;
                other.source = "";
            }
        }
    }
}
