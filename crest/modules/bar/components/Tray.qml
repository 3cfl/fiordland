pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Caelestia.Config
import qs.components
import qs.services

StyledRect {
    id: root

    readonly property alias layout: layout
    readonly property alias items: items
    readonly property int padding: Config.bar.tray.background ? Tokens.padding.medium : 0

    clip: true
    visible: items.count > 0

    implicitWidth: items.count > 0 ? layout.implicitWidth + padding * 2 : 0
    implicitHeight: Tokens.sizes.bar.innerWidth - Tokens.padding.small * 2

    color: Qt.alpha(Colours.tPalette.m3surfaceContainer, (Config.bar.tray.background && items.count > 0) ? Colours.tPalette.m3surfaceContainer.a : 0)
    radius: Tokens.rounding.full

    Row {
        id: layout

        anchors.centerIn: parent
        spacing: Tokens.spacing.medium

        add: Transition {
            Anim {
                properties: "scale"
                from: 0
                to: 1
                easing: Tokens.anim.standardDecel
            }
        }

        move: Transition {
            Anim {
                properties: "x,y"
            }
        }

        Repeater {
            id: items

            model: ScriptModel {
                values: SystemTray.items.values.filter(i => i.status !== Status.Passive && !GlobalConfig.bar.tray.hiddenIcons.includes(i.id))
            }

            TrayItem {}
        }
    }

    Behavior on implicitWidth {
        Anim {}
    }
}
