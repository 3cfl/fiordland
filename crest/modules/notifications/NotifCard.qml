pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Widgets
import qs.components
import qs.theme

Item {
    id: root

    required property var entry
    property bool glass: true
    property bool expanded: false
    readonly property bool critical: entry.urgency === NotificationUrgency.Critical
    readonly property string ago: {
        const s = Math.max(0, Math.floor((now - entry.time.getTime()) / 1000));
        if (s < 60)
            return "now";
        if (s < 3600)
            return `${Math.floor(s / 60)} min`;
        if (s < 86400)
            return `${Math.floor(s / 3600)} h`;
        return Qt.formatDate(entry.time, "d MMM");
    }
    property real now: Date.now()

    signal dismissed

    implicitWidth: 380
    implicitHeight: card.implicitHeight

    Timer {
        interval: 30000
        repeat: true
        running: root.visible
        onTriggered: root.now = Date.now()
    }

    Glass {
        id: card

        width: parent.width
        implicitHeight: body.implicitHeight + 28
        x: drag.active ? card.x : 0
        radius: Style.rXl
        shadow: root.glass
        highlight: root.glass
        tint: root.critical ? Colours.errorContainer : (root.glass ? Colours.surfaceContainer : Colours.surfaceContainerHigh)
        alpha: root.glass ? Style.glassAlpha : 0.7
        opacity: 1 - Math.min(0.8, Math.abs(x) / width)

        Behavior on x {
            enabled: !drag.active
            SpringDefault {}
        }

        DragHandler {
            id: drag

            xAxis.enabled: true
            yAxis.enabled: false
            onActiveChanged: {
                if (!active) {
                    if (Math.abs(card.x) > card.width * 0.35)
                        root.entry.dismiss();
                    else
                        card.x = 0;
                }
            }
        }

        HoverHandler {
            id: hover
        }

        TapHandler {
            onTapped: root.expanded = !root.expanded
        }

        RowLayout {
            id: body

            x: 14
            y: 14
            width: parent.width - 28
            spacing: 12

            Item {
                Layout.preferredWidth: 42
                Layout.preferredHeight: 42
                Layout.alignment: Qt.AlignTop

                ExprShape {
                    anchors.fill: parent
                    shape: root.critical ? "sunny" : "cookie4"
                    color: root.critical ? Colours.error : Colours.primaryContainer
                    visible: img.status !== Image.Ready
                }

                IconImage {
                    id: appIcon

                    anchors.centerIn: parent
                    implicitSize: 24
                    visible: img.status !== Image.Ready && root.entry.appIcon !== "" && status === Image.Ready
                    source: root.entry.appIcon ? Quickshell.iconPath(root.entry.appIcon, true) : ""
                    asynchronous: true
                }

                Icon {
                    anchors.centerIn: parent
                    visible: img.status !== Image.Ready && !appIcon.visible
                    name: root.critical ? "priority_high" : "notifications"
                    fill: 1
                    size: 22
                    color: root.critical ? Colours.onError : Colours.onPrimaryContainer
                }

                Image {
                    id: img

                    anchors.fill: parent
                    source: root.entry.image
                    sourceSize.width: 84
                    sourceSize.height: 84
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: false
                }

                Rectangle {
                    id: imgMask

                    anchors.fill: parent
                    radius: width / 2
                    visible: false
                    layer.enabled: true
                }

                MultiEffect {
                    anchors.fill: parent
                    visible: img.status === Image.Ready
                    source: img
                    maskEnabled: true
                    maskSource: imgMask
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Txt {
                        text: root.entry.appName || "notification"
                        role: "labelM"
                        color: root.critical ? Colours.onErrorContainer : Colours.primary
                        elide: Text.ElideNone
                    }

                    Txt {
                        Layout.fillWidth: true
                        text: "· " + root.ago
                        role: "labelM"
                        color: root.critical ? Colours.onErrorContainer : Colours.onSurfaceVariant
                    }

                    Rectangle {
                        Layout.preferredWidth: 24
                        Layout.preferredHeight: 24
                        radius: 12
                        opacity: hover.hovered ? 1 : 0
                        color: Colours.alpha(Colours.onSurface, closeArea.containsMouse ? 0.16 : 0.08)

                        Behavior on opacity {
                            Ease {
                                duration: Motion.durShort
                            }
                        }

                        Icon {
                            anchors.centerIn: parent
                            name: "close"
                            size: 16
                            color: Colours.onSurface
                        }

                        MouseArea {
                            id: closeArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.entry.dismiss()
                        }
                    }
                }

                Txt {
                    Layout.fillWidth: true
                    text: root.entry.summary
                    role: "titleS"
                    color: root.critical ? Colours.onErrorContainer : Colours.onSurface
                }

                Txt {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: root.entry.body
                    role: "bodyM"
                    color: root.critical ? Colours.onErrorContainer : Colours.onSurfaceVariant
                    wrapMode: Text.Wrap
                    maximumLineCount: root.expanded ? 12 : 2
                }

                Flow {
                    Layout.fillWidth: true
                    Layout.topMargin: 6
                    visible: root.entry.actions.length > 0
                    spacing: 6

                    Repeater {
                        model: root.entry.actions

                        PillButton {
                            required property var modelData

                            size: 32
                            variant: "tonal"
                            text: modelData.text
                            onClicked: root.entry.invoke(modelData)
                        }
                    }
                }
            }
        }
    }
}
