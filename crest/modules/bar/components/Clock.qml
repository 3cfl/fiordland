pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services

StyledRect {
    id: root

    required property ScreenState screenState
    readonly property color colour: Colours.palette.m3onSurface

    implicitWidth: layout.implicitWidth + Tokens.padding.large * 2
    implicitHeight: Tokens.sizes.bar.innerWidth - Tokens.padding.small * 2

    color: root.screenState.dashboard ? Colours.tPalette.m3surfaceContainerHigh : Qt.alpha(Colours.tPalette.m3surfaceContainer, Config.bar.clock.background ? Colours.tPalette.m3surfaceContainer.a : 0)
    radius: Tokens.rounding.full

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.screenState.dashboard = !root.screenState.dashboard
    }

    RowLayout {
        id: layout

        anchors.centerIn: parent
        spacing: Tokens.spacing.medium

        MaterialIcon {
            visible: Config.bar.clock.showIcon
            text: "calendar_month"
            color: Colours.palette.m3primary
        }

        StyledText {
            visible: Config.bar.clock.showDate
            text: Time.format("ddd d MMM")
            font: Tokens.font.body.small
            color: Colours.palette.m3onSurfaceVariant
        }

        StyledText {
            text: Time.format(Units.twelveHourClock ? (Config.bar.clock.showSeconds ? "h:mm:ss AP" : "h:mm AP") : (Config.bar.clock.showSeconds ? "HH:mm:ss" : "HH:mm"))
            font: Tokens.font.title.small
            color: root.colour
        }
    }
}
