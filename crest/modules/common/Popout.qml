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
    property bool keepAlive: false
    readonly property bool shown: open || progress > 0.002
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
        active: root.keepAlive || root.shown

        PanelWindow {
            id: win

            visible: root.shown
            screen: Panels.screen
            color: "transparent"
            WlrLayershell.namespace: "crest-" + root.name
            WlrLayershell.layer: root.fill ? WlrLayer.Overlay : WlrLayer.Top
            WlrLayershell.keyboardFocus: root.open && root.interactive && !Session.locked ? (root.exclusiveKeyboard ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand) : WlrKeyboardFocus.None
            exclusionMode: root.fill ? ExclusionMode.Ignore : ExclusionMode.Normal
            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true

            property Region cardRegion: Region {
                item: holder
            }
            property Region emptyRegion: Region {}

            mask: root.fill ? null : (root.interactive ? cardRegion : emptyRegion)

            HyprlandFocusGrab {
                active: root.open && root.interactive && !Config.demo && !Capture.selecting && !Session.locked
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

                implicitWidth: loader.implicitWidth
                implicitHeight: loader.implicitHeight
                x: root.fill ? 0 : (root.edge === "top-left" ? root.padL : root.edge === "top-right" ? win.width - root.padR - width : Math.round((win.width - width) / 2))
                y: root.fill ? 0 : (root.edge === "bottom" ? win.height - root.padB - height : root.padT)
                width: root.fill ? parent.width : implicitWidth
                height: root.fill ? parent.height : implicitHeight
                focus: true
                opacity: Math.min(1, root.progress * 1.6)
                scale: 0.9 + 0.1 * Math.min(1, root.progress)
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

                Binding {
                    target: loader.item
                    property: "live"
                    value: root.shown
                    when: loader.item !== null && loader.item.hasOwnProperty("live")
                }
            }
        }
    }
}
