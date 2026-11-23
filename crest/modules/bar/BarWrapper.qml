pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import qs.components
import qs.utils
import qs.modules.bar.popouts as BarPopouts

Item {
    id: root

    required property ShellScreen screen
    required property ScreenState screenState
    required property BarPopouts.Wrapper popouts
    required property bool fullscreen

    readonly property bool disabled: Strings.testRegexList(Config.bar.excludedScreens, screen.name)

    readonly property int edge: Config.border.thickness
    readonly property int clampedHeight: Math.max(Config.border.minThickness, implicitHeight)
    readonly property int contentHeight: Tokens.sizes.bar.innerWidth
    readonly property int exclusiveZone: !disabled && (Config.bar.persistent || screenState.bar) ? contentHeight + edge : edge
    readonly property bool shouldBeVisible: !fullscreen && !disabled && (Config.bar.persistent || screenState.bar || isHovered)
    readonly property real pillHeight: Math.max(0, implicitHeight - edge)
    property bool isHovered

    function closeTray(): void {
        (content.item as Bar)?.closeTray();
    }

    function checkPopout(x: real): void {
        (content.item as Bar)?.checkPopout(x - edge);
    }

    function handleWheel(x: real, angleDelta: point): void {
        (content.item as Bar)?.handleWheel(x - edge, angleDelta);
    }

    function overClock(x: real): bool {
        return (content.item as Bar)?.overClock(x - edge) ?? false;
    }

    clip: true
    visible: pillHeight > 0
    implicitHeight: fullscreen ? 0 : edge

    states: State {
        name: "visible"
        when: root.shouldBeVisible

        PropertyChanges {
            root.implicitHeight: root.contentHeight + root.edge
        }
    }

    transitions: [
        Transition {
            from: ""
            to: "visible"

            Anim {
                target: root
                property: "implicitHeight"
            }
        },
        Transition {
            from: "visible"
            to: ""

            Anim {
                target: root
                property: "implicitHeight"
                type: Anim.Emphasized
            }
        }
    ]

    Loader {
        id: content

        x: root.edge
        anchors.bottom: parent.bottom
        width: root.width - root.edge * 2
        height: root.contentHeight

        active: root.shouldBeVisible

        sourceComponent: Bar {
            screen: root.screen
            screenState: root.screenState
            popouts: root.popouts
            fullscreen: root.fullscreen
        }
    }
}
