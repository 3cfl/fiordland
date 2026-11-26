pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.components
import qs.services
import qs.theme

Glass {
    id: root

    property bool live: true
    readonly property string tab: Panels.dashboardTab
    readonly property var tabs: [
        { id: "home", icon: "home", label: "home" },
        { id: "media", icon: "music_note", label: "music" },
        { id: "system", icon: "monitoring", label: "system" },
        { id: "clipboard", icon: "content_paste", label: "clips" }
    ]

    signal done

    implicitWidth: 860
    implicitHeight: Math.max(rail.implicitHeight, pages.implicitHeight) + 24
    radius: Style.rXl
    focus: true

    Behavior on implicitHeight {
        SpringDefault {}
    }

    Keys.onPressed: event => {
        if (event.modifiers & Qt.ControlModifier && (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab)) {
            const i = tabs.findIndex(t => t.id === root.tab);
            const step = event.key === Qt.Key_Backtab || event.modifiers & Qt.ShiftModifier ? -1 : 1;
            Panels.dashboardTab = tabs[(i + step + tabs.length) % tabs.length].id;
            event.accepted = true;
        }
    }

    Rectangle {
        id: railBg

        x: 12
        y: 12
        width: 76
        height: parent.height - 24
        radius: Style.rXl - 10
        color: Colours.alpha(Colours.surfaceContainerHighest, 0.45)
    }

    ColumnLayout {
        id: rail

        x: railBg.x
        y: railBg.y + 10
        width: railBg.width
        height: railBg.height - 20
        spacing: 6

        Repeater {
            model: root.tabs

            Item {
                id: dest

                required property var modelData
                readonly property bool selected: root.tab === modelData.id

                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 64
                Layout.preferredHeight: 58

                Rectangle {
                    id: pill

                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 2
                    width: dest.selected ? 56 : 32
                    height: 32
                    radius: 16
                    color: dest.selected ? Colours.secondaryContainer : "transparent"

                    Behavior on width {
                        SpringFast {}
                    }

                    Behavior on color {
                        ColorEase {}
                    }
                }

                Icon {
                    anchors.centerIn: pill
                    name: dest.modelData.icon
                    size: 22
                    fill: dest.selected ? 1 : 0
                    color: dest.selected ? Colours.fgSecondaryContainer : Colours.fgSurfaceVariant
                }

                Rectangle {
                    visible: dest.modelData.id === "home" && Notifs.count > 0 && !dest.selected
                    x: pill.x + pill.width - 8
                    y: pill.y + 3
                    width: 8
                    height: 8
                    radius: 4
                    color: Colours.tertiary
                }

                Txt {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 38
                    text: dest.modelData.label
                    role: "labelM"
                    color: dest.selected ? Colours.fgSurface : Colours.fgSurfaceVariant
                    elide: Text.ElideNone
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Panels.dashboardTab = dest.modelData.id
                }
            }
        }

        Item {
            Layout.fillHeight: true
        }

        IconButton {
            Layout.alignment: Qt.AlignHCenter
            icon: "settings"
            size: 40
            iconSize: 20
            onClicked: Panels.openSettings(root.tab === "system" ? "bar" : "appearance")
        }
    }

    ColumnLayout {
        id: pages

        x: railBg.x + railBg.width + 16
        y: 16
        width: parent.width - x - 16
        spacing: 0

        Loader {
            Layout.fillWidth: true
            active: root.live && root.tab === "home"
            visible: active
            sourceComponent: HomePage {}
        }

        Loader {
            Layout.fillWidth: true
            active: root.live && root.tab === "media"
            visible: active
            focus: active
            sourceComponent: MediaPage {}
        }

        Loader {
            Layout.fillWidth: true
            active: root.live && root.tab === "system"
            visible: active
            sourceComponent: SystemPage {}
        }

        Loader {
            Layout.fillWidth: true
            active: root.live && root.tab === "clipboard"
            visible: active
            focus: active
            sourceComponent: ClipboardPage {
                onDone: root.done()
            }
        }
    }
}
