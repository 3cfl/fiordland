pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Caelestia.Config
import qs.components
import qs.services

StyledRect {
    id: root

    required property ShellScreen screen
    required property bool fullscreen

    readonly property HyprlandMonitor monitor: Hypr.monitorFor(screen)
    readonly property int activeWsId: monitor?.activeWorkspace?.id ?? 1
    readonly property bool onSpecial: (monitor?.lastIpcObject.specialWorkspace?.name ?? "") !== ""
    readonly property int shown: Math.max(1, Config.bar.workspaces.shown)
    readonly property int groupOffset: Math.floor((Math.max(1, activeWsId) - 1) / shown) * shown
    readonly property int dot: 10

    implicitWidth: row.implicitWidth + Tokens.padding.large * 2
    implicitHeight: Tokens.sizes.bar.innerWidth - Tokens.padding.small * 2

    color: Colours.tPalette.m3surfaceContainer
    radius: Tokens.rounding.full

    Row {
        id: row

        anchors.centerIn: parent
        spacing: Tokens.spacing.small
        opacity: root.onSpecial ? 0.45 : 1

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }

        Repeater {
            model: root.shown

            Item {
                id: ws

                required property int index
                readonly property int wsId: root.groupOffset + index + 1
                readonly property bool active: wsId === root.activeWsId
                readonly property bool occupied: Hypr.workspaces.values.some(w => w.id === wsId && w.toplevels.values.length > 0)

                implicitWidth: active ? root.dot * 2.8 : root.dot
                implicitHeight: root.dot

                Behavior on implicitWidth {
                    Anim {}
                }

                StyledRect {
                    anchors.fill: parent
                    radius: height / 2
                    color: ws.active ? Colours.palette.m3primary : ws.occupied ? Colours.palette.m3onSurfaceVariant : Qt.alpha(Colours.palette.m3onSurfaceVariant, 0.28)
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -Tokens.padding.small
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (Hypr.activeWsId !== ws.wsId)
                            Hypr.focusWorkspace(ws.wsId);
                        else
                            Hypr.toggleSpecial("special");
                    }
                }
            }
        }
    }
}
