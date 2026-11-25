pragma ComponentBehavior: Bound

import QtQuick
import qs.theme

Item {
    id: root

    property real value: 0
    property string icon
    property bool showValue: false
    readonly property bool dragging: area.pressed
    property real shown: value
    readonly property real gap: 5
    readonly property real handleW: dragging ? 3 : 4
    readonly property real travel: width - handleW
    readonly property real hx: Math.max(0, Math.min(1, shown)) * travel

    signal moved(real value)

    implicitWidth: 240
    implicitHeight: 44

    Behavior on shown {
        enabled: !root.dragging
        SpringDefault {}
    }

    Binding on shown {
        when: !root.dragging
        value: root.value
    }

    Rectangle {
        id: active

        x: 0
        width: Math.max(0, root.hx - root.gap)
        height: parent.height
        visible: width > 1
        color: Colours.primary
        topLeftRadius: height / 2
        bottomLeftRadius: height / 2
        topRightRadius: Math.min(Style.rXs, width / 2)
        bottomRightRadius: Math.min(Style.rXs, width / 2)
    }

    Rectangle {
        id: inactive

        x: root.hx + root.handleW + root.gap
        width: Math.max(0, root.width - x)
        height: parent.height
        visible: width > 1
        color: Colours.secondaryContainer
        topRightRadius: height / 2
        bottomRightRadius: height / 2
        topLeftRadius: Math.min(Style.rXs, width / 2)
        bottomLeftRadius: Math.min(Style.rXs, width / 2)

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: (parent.height - height) / 2
            width: 6
            height: 6
            radius: 3
            visible: !root.showValue && parent.width > parent.height
            color: Colours.fgSecondaryContainer
        }
    }

    Rectangle {
        x: root.hx
        anchors.verticalCenter: parent.verticalCenter
        width: root.handleW
        height: parent.height + 10
        radius: width / 2
        color: Colours.primary

        Behavior on width {
            SpringFast {}
        }
    }

    Icon {
        visible: root.icon !== ""
        anchors.verticalCenter: parent.verticalCenter
        x: 12
        name: root.icon
        size: 22
        fill: 1
        color: active.width > x + width + 4 ? Colours.fgPrimary : Colours.fgSecondaryContainer
    }

    Txt {
        visible: root.showValue
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        anchors.rightMargin: 22
        text: Math.round(root.value * 100)
        role: "labelM"
        color: root.hx > root.width - 48 ? Colours.fgPrimary : Colours.fgSecondaryContainer
    }

    MouseArea {
        id: area

        anchors.fill: parent
        anchors.topMargin: -6
        anchors.bottomMargin: -6
        cursorShape: Qt.PointingHandCursor
        preventStealing: true

        function update(mx: real): void {
            const v = Math.max(0, Math.min(1, (mx - root.handleW / 2) / root.travel));
            root.shown = v;
            root.moved(v);
        }

        onPressed: mouse => update(mouse.x)
        onPositionChanged: mouse => {
            if (pressed)
                update(mouse.x);
        }
        onWheel: wheel => {
            const v = Math.max(0, Math.min(1, root.value + (wheel.angleDelta.y > 0 ? 0.05 : -0.05)));
            root.moved(v);
        }
    }
}
