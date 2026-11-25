pragma ComponentBehavior: Bound

import QtQuick
import qs.components
import qs.config
import qs.services
import qs.theme

Item {
    id: root

    readonly property int slot: 22
    readonly property int pillWidth: 38
    readonly property int count: Math.max(Config.bar.workspaces, Math.min(10, Hypr.activeId), Object.keys(Hypr.occupied).reduce((m, k) => Math.max(m, Math.min(10, parseInt(k))), 0))
    readonly property int active: Hypr.activeId
    readonly property real targetLeft: (active - 1) * slot
    property real lead: targetLeft
    property real trail: targetLeft

    implicitWidth: count * slot + pillWidth - slot
    implicitHeight: 28

    Behavior on lead {
        SpringFast {}
    }

    Behavior on trail {
        SpringDefault {}
    }

    function slotX(i: int): real {
        return i * slot + (i + 1 > active ? pillWidth - slot : 0);
    }

    Rectangle {
        id: pill

        readonly property real from: Math.min(root.lead, root.trail)
        readonly property real to: Math.max(root.lead, root.trail) + root.pillWidth

        x: from
        width: to - from
        height: root.height
        radius: height / 2
        color: Colours.primary

        Txt {
            anchors.centerIn: parent
            text: root.active
            role: "labelL"
            emphasis: true
            color: Colours.fgPrimary
        }
    }

    Repeater {
        model: root.count

        Item {
            id: ws

            required property int index
            readonly property int number: index + 1
            readonly property bool isActive: number === root.active
            readonly property int windows: Hypr.occupied[String(number)] ?? 0

            x: root.slotX(index)
            width: isActive ? root.pillWidth : root.slot
            height: root.height

            Behavior on x {
                SpringDefault {}
            }

            Rectangle {
                anchors.centerIn: parent
                visible: !ws.isActive
                width: ws.windows > 0 ? 8 : 6
                height: width
                radius: width / 2
                color: ws.windows > 0 ? Colours.fgSurfaceVariant : Colours.alpha(Colours.outline, 0.6)
                scale: hover.containsMouse ? 1.35 : 1

                Behavior on scale {
                    SpringFast {}
                }
            }

            MouseArea {
                id: hover

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Hypr.workspace(ws.number)
            }
        }
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => Hypr.relative(event.angleDelta.y > 0 ? -1 : 1)
    }
}
