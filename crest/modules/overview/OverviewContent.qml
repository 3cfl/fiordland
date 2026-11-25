pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.components
import qs.config
import qs.services
import qs.theme

Item {
    id: root

    readonly property int columns: 5
    readonly property int rows: 2
    readonly property real monW: Panels.screen?.width ?? 1920
    readonly property real monH: Panels.screen?.height ?? 1080
    readonly property real cellW: Math.min(300, (width - 160) / columns)
    readonly property real cellH: cellW * monH / monW
    readonly property var windows: Config.demo ? demoWindows : Hypr.toplevels.map(t => {
        const o = t.lastIpcObject ?? {};
        return {
            address: t.address,
            workspace: t.workspace?.id ?? 0,
            title: t.title,
            cls: o.class ?? "",
            x: (o.at?.[0] ?? 0) - (Panels.screen?.x ?? 0),
            y: (o.at?.[1] ?? 0) - (Panels.screen?.y ?? 0),
            w: o.size?.[0] ?? 100,
            h: o.size?.[1] ?? 100
        };
    })
    readonly property var demoWindows: [
        { address: "1", workspace: 1, title: "kitty", cls: "kitty", x: 10, y: 60, w: 940, h: 1010 },
        { address: "2", workspace: 1, title: "Firefox", cls: "firefox", x: 970, y: 60, w: 940, h: 1010 },
        { address: "3", workspace: 2, title: "Thunar", cls: "thunar", x: 10, y: 60, w: 1900, h: 1010 },
        { address: "4", workspace: 4, title: "Discord", cls: "discord", x: 200, y: 160, w: 1500, h: 800 }
    ]

    signal done

    focus: true
    Keys.onEscapePressed: done()
    Keys.onLeftPressed: Hypr.relative(-1)
    Keys.onRightPressed: Hypr.relative(1)

    Component.onCompleted: {
        if (!Config.demo)
            Hypr.refresh();
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.done()
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 20

        Txt {
            Layout.alignment: Qt.AlignHCenter
            text: "workspaces"
            role: "titleL"
            color: Colours.fgSurface
        }

        GridLayout {
            columns: root.columns
            rowSpacing: 16
            columnSpacing: 16

            Repeater {
                model: root.columns * root.rows

                Glass {
                    id: ws

                    required property int index
                    readonly property int number: index + 1
                    readonly property bool active: Hypr.activeId === number
                    readonly property var mine: root.windows.filter(w => w.workspace === number)

                    Layout.preferredWidth: root.cellW
                    Layout.preferredHeight: root.cellH
                    radius: Style.rXl
                    tint: active ? Colours.primaryContainer : Colours.surfaceContainer
                    shadow: active

                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: "transparent"
                        border.width: ws.active ? 3 : 0
                        border.color: Colours.primary
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Hypr.workspace(ws.number);
                            root.done();
                        }
                    }

                    Txt {
                        anchors.centerIn: parent
                        visible: ws.mine.length === 0
                        text: ws.number
                        role: "headlineM"
                        color: Colours.fgSurfaceVariant
                        opacity: 0.6
                    }

                    Item {
                        anchors.fill: parent
                        anchors.margins: 6

                        Repeater {
                            model: ws.mine

                            Rectangle {
                                id: win

                                required property var modelData
                                readonly property real sx: parent.width / root.monW
                                readonly property real sy: parent.height / root.monH

                                x: modelData.x * sx
                                y: modelData.y * sy
                                width: Math.max(16, modelData.w * sx - 2)
                                height: Math.max(16, modelData.h * sy - 2)
                                radius: Style.rMd
                                color: winArea.containsMouse ? Colours.secondaryContainer : Colours.alpha(Colours.surfaceContainerHighest, 0.92)
                                border.width: 1
                                border.color: Colours.alpha(Colours.fgSurface, 0.1)

                                IconImage {
                                    anchors.centerIn: parent
                                    implicitSize: Math.min(40, Math.min(parent.width, parent.height) * 0.5)
                                    source: Quickshell.iconPath(win.modelData.cls.toLowerCase(), "application-x-executable")
                                    asynchronous: true
                                }

                                MouseArea {
                                    id: winArea

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        Hypr.focusWindow(win.modelData.address);
                                        root.done();
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
