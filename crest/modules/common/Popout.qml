pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.config
import qs.services
import qs.theme

Scope {
    id: root

    required property string name
    property bool open: false
    property string edge: "top-right"
    property bool exclusiveKeyboard: false
    property bool scrim: edge === "fill"
    property bool interactive: true
    property int offset: 0
    property Component content
    property real progress: 0
    readonly property bool fill: edge === "fill"
    readonly property int padL: fill ? 0 : (edge === "top-left" ? 12 : 40)
    readonly property int padR: fill ? 0 : (edge === "top-right" ? 12 : 40)
    readonly property int padT: fill ? 0 : (edge === "bottom" ? 40 : 8 + offset)
    readonly property int padB: fill ? 0 : (edge === "bottom" ? 24 + offset : 48)

    signal dismissed

    onOpenChanged: {
        if (open) {
            closeAnim.stop();
            openAnim.restart();
        } else {
            openAnim.stop();
            closeAnim.restart();
        }
    }

    SpringAnimation {
        id: openAnim

        target: root
        property: "progress"
        to: 1
        spring: Motion.defaultSpring
        damping: Motion.defaultDamping
        epsilon: 0.005
    }

    NumberAnimation {
        id: closeAnim

        target: root
        property: "progress"
        to: 0
        duration: Motion.durShort
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Motion.emphasizedAccel
    }

    LazyLoader {
        active: root.open || root.progress > 0.002

        PanelWindow {
            id: win

            screen: Panels.screen
            color: "transparent"
            WlrLayershell.namespace: "crest-" + root.name
            WlrLayershell.layer: root.fill ? WlrLayer.Overlay : WlrLayer.Top
            WlrLayershell.keyboardFocus: root.open && root.interactive ? (root.exclusiveKeyboard ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand) : WlrKeyboardFocus.None
            exclusionMode: root.fill ? ExclusionMode.Ignore : ExclusionMode.Normal
            anchors.top: root.fill || root.edge.startsWith("top")
            anchors.bottom: root.fill || root.edge === "bottom"
            anchors.left: root.fill || root.edge === "top-left"
            anchors.right: root.fill || root.edge === "top-right"
            implicitWidth: holder.implicitWidth + root.padL + root.padR
            implicitHeight: holder.implicitHeight + root.padT + root.padB

            property Region cardRegion: Region {
                item: holder
            }
            property Region emptyRegion: Region {}

            mask: root.fill ? null : (root.interactive ? cardRegion : emptyRegion)

            HyprlandFocusGrab {
                active: root.open && root.interactive && !Config.demo
                windows: [win]
                onCleared: root.dismissed()
            }

            Rectangle {
                anchors.fill: parent
                visible: root.scrim
                color: Colours.scrim
                opacity: 0.4 * Math.min(1, root.progress)

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.dismissed()
                }
            }

            Item {
                id: holder

                readonly property Item item: loader.item

                implicitWidth: loader.implicitWidth
                implicitHeight: loader.implicitHeight
                x: root.fill ? 0 : root.padL
                y: root.fill ? 0 : root.padT
                width: root.fill ? parent.width : implicitWidth
                height: root.fill ? parent.height : implicitHeight
                focus: true
                opacity: Math.min(1, root.progress * 1.6)
                scale: 0.9 + 0.1 * root.progress
                transformOrigin: root.edge === "top-right" ? Item.TopRight : root.edge === "top-left" ? Item.TopLeft : root.edge === "bottom" ? Item.Bottom : root.edge === "top" ? Item.Top : Item.Center
                Keys.onEscapePressed: root.dismissed()

                transform: Translate {
                    y: root.fill ? 0 : (1 - root.progress) * (root.edge === "bottom" ? 18 : -18)
                }

                Loader {
                    id: loader

                    anchors.fill: parent
                    focus: true
                    sourceComponent: root.content
                }
            }
        }
    }
}
