pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.components
import qs.modules.bar.popouts

Item {
    id: root

    required property ShellScreen screen
    required property real borderThickness

    readonly property alias content: content
    property real offsetScale: content.isDetached || content.hasCurrent ? 0 : 1

    visible: width > 0 && height > 0
    clip: true

    implicitWidth: content.implicitWidth
    implicitHeight: content.implicitHeight * (1 - offsetScale)

    x: {
        if (content.isDetached)
            return (parent.width - content.nonAnimWidth) / 2;

        const off = content.currentCenter - content.nonAnimWidth / 2;
        return Math.max(0, Math.min(off, parent.width - content.nonAnimWidth));
    }
    y: content.isDetached ? (parent.height - content.nonAnimHeight) / 2 : 0

    Behavior on offsetScale {
        Anim {}
    }

    Behavior on x {
        enabled: root.offsetScale < 1

        Anim {
            duration: content.animLength
            easing: content.animCurve
        }
    }

    Behavior on y {
        Anim {
            duration: content.animLength
            easing: content.animCurve
        }
    }

    Wrapper {
        id: content

        screen: root.screen
        offsetScale: root.offsetScale

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
    }
}
