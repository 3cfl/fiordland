pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.components
import qs.services
import qs.theme

ColumnLayout {
    id: root

    spacing: 12

    Component.onCompleted: {
        SysStats.detailed = true;
        SysStats.acquire();
    }
    Component.onDestruction: {
        SysStats.release();
        SysStats.detailed = false;
    }

    component Gauge: Rectangle {
        id: gauge

        property string label
        property string icon
        property real value: 0
        property string detail
        property color accent: Colours.primary
        property color soft: Colours.primaryContainer
        property bool known: true

        Layout.fillWidth: true
        implicitHeight: 176
        radius: Style.rLgInc
        color: Colours.alpha(Colours.surfaceContainerHighest, 0.5)

        WavyRing {
            id: ring

            anchors.horizontalCenter: parent.horizontalCenter
            y: 14
            width: 104
            height: 104
            value: gauge.known ? gauge.value : 0
            color: gauge.accent
            trackColor: Colours.alpha(gauge.accent, 0.18)
            thickness: 7
            amplitude: gauge.value > 0.75 ? 3 : 2
            waves: 9
            animating: gauge.value > 0.05

            Column {
                anchors.centerIn: parent
                spacing: -2

                Txt {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: gauge.known ? `${Math.round(gauge.value * 100)}%` : "–"
                    role: "titleL"
                    emphasis: true
                    elide: Text.ElideNone
                }
            }
        }

        Txt {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: ring.bottom
            anchors.topMargin: 8
            text: gauge.label
            role: "labelL"
            emphasis: true
            elide: Text.ElideNone
        }

        Txt {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 10
            width: parent.width - 16
            horizontalAlignment: Text.AlignHCenter
            text: gauge.detail
            role: "labelS"
            color: Colours.fgSurfaceVariant
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 12

        Gauge {
            label: "cpu"
            icon: "memory"
            value: SysStats.cpu
            detail: SysStats.cpuTemp > 0 ? `${SysStats.cpuTemp}°C` : SysStats.cpuName.split(" ").slice(0, 3).join(" ")
        }

        Gauge {
            label: SysStats.gpuVendor ? `gpu · ${SysStats.gpuVendor.toLowerCase()}` : "gpu"
            icon: "developer_board"
            value: Math.max(0, SysStats.gpu)
            known: SysStats.gpu >= 0
            accent: Colours.tertiary
            detail: SysStats.gpuTemp > 0 ? `${SysStats.gpuTemp}°C` : SysStats.gpuMemTotal > 0 ? `${SysStats.bytes(SysStats.gpuMemUsed)} vram` : (SysStats.gpu >= 0 ? "busy" : "not supported")
        }

        Gauge {
            label: "memory"
            icon: "memory_alt"
            value: SysStats.memory
            accent: Colours.secondary
            detail: `${SysStats.bytes(SysStats.memUsed)} / ${SysStats.bytes(SysStats.memTotal)}`
        }
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 112
        radius: Style.rLgInc
        color: Colours.alpha(Colours.surfaceContainerHighest, 0.5)
        clip: true

        Row {
            x: 16
            y: 12
            spacing: 14

            Repeater {
                model: [
                    { name: "cpu", c: Colours.primary },
                    { name: "gpu", c: Colours.tertiary },
                    { name: "memory", c: Colours.secondary }
                ]

                Row {
                    required property var modelData

                    spacing: 6

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 10
                        height: 10
                        radius: 5
                        color: parent.modelData.c
                    }

                    Txt {
                        text: parent.modelData.name
                        role: "labelM"
                        color: Colours.fgSurfaceVariant
                        elide: Text.ElideNone
                    }
                }
            }
        }

        Txt {
            anchors.right: parent.right
            anchors.rightMargin: 16
            y: 12
            text: SysStats.uptime > 0 ? `up ${SysStats.duration(SysStats.uptime)}` : ""
            role: "labelM"
            color: Colours.fgSurfaceVariant
            elide: Text.ElideNone
        }

        Sparkline {
            anchors.fill: parent
            anchors.topMargin: 36
            values: SysStats.history.map(h => h.memory ?? h.mem)
            color: Colours.secondary
            filled: false
            thickness: 2
        }

        Sparkline {
            anchors.fill: parent
            anchors.topMargin: 36
            visible: SysStats.gpu >= 0
            values: SysStats.history.map(h => h.gpu)
            color: Colours.tertiary
            filled: false
            thickness: 2
        }

        Sparkline {
            anchors.fill: parent
            anchors.topMargin: 36
            values: SysStats.history.map(h => h.cpu)
            color: Colours.primary
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 12

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredWidth: 3
            Layout.fillHeight: true
            implicitHeight: storage.implicitHeight + 28
            radius: Style.rLgInc
            color: Colours.alpha(Colours.surfaceContainerHighest, 0.5)

            ColumnLayout {
                id: storage

                x: 16
                y: 14
                width: parent.width - 32
                spacing: 12

                RowLayout {
                    spacing: 8

                    Icon {
                        name: "hard_drive"
                        size: 20
                        fill: 1
                        color: Colours.primary
                    }

                    Txt {
                        text: "storage"
                        role: "titleS"
                        emphasis: true
                    }
                }

                Repeater {
                    model: SysStats.disks.slice(0, 4)

                    ColumnLayout {
                        id: disk

                        required property var modelData
                        readonly property real frac: modelData.size > 0 ? modelData.used / modelData.size : 0

                        Layout.fillWidth: true
                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true

                            Txt {
                                Layout.fillWidth: true
                                text: disk.modelData.name
                                role: "labelL"
                            }

                            Txt {
                                text: `${SysStats.bytes(disk.modelData.avail)} free of ${SysStats.bytes(disk.modelData.size)}`
                                role: "labelM"
                                color: Colours.fgSurfaceVariant
                                elide: Text.ElideNone
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                            implicitHeight: 12

                            Rectangle {
                                id: used

                                height: parent.height
                                width: Math.max(height, (parent.width - 4) * disk.frac)
                                radius: height / 2
                                color: disk.frac > 0.9 ? Colours.error : Colours.primary

                                Behavior on width {
                                    SpringDefault {}
                                }
                            }

                            Rectangle {
                                x: used.width + 4
                                width: Math.max(0, parent.width - x)
                                height: parent.height
                                radius: height / 2
                                color: Colours.alpha(disk.frac > 0.9 ? Colours.error : Colours.primary, 0.2)
                            }
                        }
                    }
                }

                Txt {
                    visible: SysStats.disks.length === 0
                    text: "reading disks…"
                    role: "bodyS"
                    color: Colours.fgSurfaceVariant
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredWidth: 2
            Layout.fillHeight: true
            implicitHeight: hogs.implicitHeight + 28
            radius: Style.rLgInc
            color: Colours.alpha(Colours.surfaceContainerHighest, 0.5)

            ColumnLayout {
                id: hogs

                x: 16
                y: 14
                width: parent.width - 32
                spacing: 8

                RowLayout {
                    spacing: 8

                    Icon {
                        name: "leaderboard"
                        size: 20
                        fill: 1
                        color: Colours.secondary
                    }

                    Txt {
                        text: "top memory"
                        role: "titleS"
                        emphasis: true
                    }
                }

                Repeater {
                    model: SysStats.hogs

                    RowLayout {
                        id: hog

                        required property var modelData
                        required property int index

                        Layout.fillWidth: true
                        spacing: 8

                        Rectangle {
                            implicitWidth: 22
                            implicitHeight: 22
                            radius: 11
                            color: hog.index === 0 ? Colours.secondaryContainer : Colours.alpha(Colours.fgSurface, 0.08)

                            Txt {
                                anchors.centerIn: parent
                                text: hog.index + 1
                                role: "labelS"
                                color: hog.index === 0 ? Colours.fgSecondaryContainer : Colours.fgSurfaceVariant
                                elide: Text.ElideNone
                            }
                        }

                        Txt {
                            Layout.fillWidth: true
                            text: hog.modelData.name
                            role: "labelL"
                        }

                        Txt {
                            text: SysStats.bytes(hog.modelData.rss)
                            role: "labelM"
                            color: Colours.fgSurfaceVariant
                            elide: Text.ElideNone
                        }
                    }
                }
            }
        }
    }
}
