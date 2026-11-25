pragma ComponentBehavior: Bound

import QtQuick
import qs.theme

Item {
    id: root

    property string icon
    property int size: 40
    property int iconSize: Math.round(size * 0.55)
    property string variant: "standard"
    property bool checkable: false
    property bool checked: false
    property bool wide: false
    property color iconColor: {
        if (checkable && checked)
            return Colours.fgPrimary;
        if (variant === "filled")
            return Colours.fgPrimary;
        if (variant === "tonal")
            return Colours.fgSecondaryContainer;
        return Colours.fgSurfaceVariant;
    }
    property color background: {
        if (checkable && checked)
            return Colours.primary;
        if (variant === "filled")
            return Colours.primary;
        if (variant === "tonal")
            return Colours.secondaryContainer;
        if (checkable)
            return Colours.surfaceContainerHighest;
        return "transparent";
    }
    readonly property bool hovered: area.containsMouse

    signal clicked
    signal rightClicked

    implicitWidth: wide ? Math.round(size * 1.4) : size
    implicitHeight: size
    opacity: enabled ? 1 : 0.38

    Rectangle {
        id: bg

        anchors.centerIn: parent
        width: root.width
        height: root.height
        color: root.background
        radius: area.pressed ? Style.rMd * root.size / 48 : (root.checkable && !root.checked ? Math.min(Style.rLg, height / 3) : height / 2)
        scale: area.pressed ? 0.94 : 1

        Behavior on radius {
            SpringFast {}
        }

        Behavior on scale {
            SpringFast {}
        }

        Behavior on color {
            ColorEase {}
        }

        StateLayer {
            id: area

            radius: bg.radius
            tint: root.iconColor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton)
                    root.rightClicked();
                else
                    root.clicked();
            }
        }

        Icon {
            anchors.centerIn: parent
            name: root.icon
            size: root.iconSize
            color: root.iconColor
            fill: root.checked || root.variant === "filled" ? 1 : 0
        }
    }
}
