import QtQuick
import QtQuick.Layouts
import qs.theme

Item {
    id: root

    property string text
    property string icon
    property string variant: "filled"
    property int size: 40
    property color foreground: {
        if (variant === "filled")
            return Colours.onPrimary;
        if (variant === "tonal")
            return Colours.onSecondaryContainer;
        if (variant === "danger")
            return Colours.onErrorContainer;
        return Colours.primary;
    }
    property color background: {
        if (variant === "filled")
            return Colours.primary;
        if (variant === "tonal")
            return Colours.secondaryContainer;
        if (variant === "danger")
            return Colours.errorContainer;
        return "transparent";
    }

    signal clicked

    implicitWidth: row.implicitWidth + (icon ? 20 : 24) * 2 - (icon ? 4 : 0)
    implicitHeight: size
    opacity: enabled ? 1 : 0.38

    Rectangle {
        id: bg

        anchors.fill: parent
        color: root.background
        radius: area.pressed ? Style.rMd : height / 2
        border.width: root.variant === "outlined" ? 1 : 0
        border.color: Colours.outlineVariant

        Behavior on radius {
            SpringFast {}
        }

        Behavior on color {
            ColorEase {}
        }

        StateLayer {
            id: area

            radius: bg.radius
            tint: root.foreground
            onClicked: root.clicked()
        }

        RowLayout {
            id: row

            anchors.centerIn: parent
            spacing: 8

            Icon {
                visible: root.icon !== ""
                name: root.icon
                size: 20
                color: root.foreground
                fill: 1
            }

            Txt {
                text: root.text
                role: "labelL"
                color: root.foreground
                elide: Text.ElideNone
            }
        }
    }
}
