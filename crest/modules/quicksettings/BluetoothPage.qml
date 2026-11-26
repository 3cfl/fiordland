pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.components
import qs.services
import qs.theme

ColumnLayout {
    id: root

    property bool live: true
    property string expanded: ""

    signal back

    spacing: 8

    onVisibleChanged: {
        Bt.scan(visible);
        if (!visible)
            expanded = "";
    }

    Binding {
        target: Bt
        property: "pageOpen"
        value: root.visible && root.live
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        IconButton {
            icon: "arrow_back"
            size: 36
            onClicked: root.back()
        }

        Txt {
            Layout.fillWidth: true
            text: "bluetooth"
            role: "titleL"
        }

        Switch {
            checked: Bt.enabled
            onToggled: on => Bt.setEnabled(on)
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: pair.implicitHeight + 36
        visible: Bt.request !== null
        radius: Style.rXl
        color: Colours.alpha(Colours.primaryContainer, 0.55)

        PairCard {
            id: pair

            x: 18
            y: 18
            width: parent.width - 36
        }
    }

    Txt {
        Layout.fillWidth: true
        Layout.leftMargin: 8
        visible: !Bt.enabled
        text: "bluetooth is off"
        role: "bodyM"
        color: Colours.fgSurfaceVariant
    }

    Section {
        visible: Bt.enabled && Bt.paired.length > 0
        title: "your devices"
    }

    Repeater {
        model: Bt.enabled ? Bt.paired : []

        DeviceRow {
            required property var modelData
            required property int index

            device: modelData
            first: index === 0
            last: index === Bt.paired.length - 1
        }
    }

    Section {
        visible: Bt.enabled
        title: "available"
        scanning: Bt.scanning
    }

    Txt {
        Layout.fillWidth: true
        Layout.leftMargin: 8
        visible: Bt.enabled && Bt.nearby.length === 0
        text: "looking for devices… put yours in pairing mode"
        role: "bodyM"
        color: Colours.fgSurfaceVariant
    }

    Repeater {
        model: Bt.enabled ? Bt.nearby : []

        DeviceRow {
            required property var modelData
            required property int index

            device: modelData
            first: index === 0
            last: index === Bt.nearby.length - 1
        }
    }

    component Section: RowLayout {
        id: section

        property string title
        property bool scanning: false

        Layout.fillWidth: true
        Layout.topMargin: 6
        Layout.leftMargin: 8
        Layout.rightMargin: 8
        spacing: 12

        Txt {
            text: section.title
            role: "labelL"
            color: Colours.primary
        }

        WavyLine {
            Layout.fillWidth: true
            visible: section.scanning
            value: 1
            amplitude: 2
            wavelength: 18
            thickness: 3
        }
    }

    component DeviceRow: Rectangle {
        id: row

        property var device
        property bool first
        property bool last
        readonly property bool open: root.expanded === device.address
        readonly property bool busy: Bt.busy(device)
        readonly property bool failed: device.address === Bt.failedAddress
        readonly property color fg: device.connected ? Colours.fgPrimaryContainer : Colours.fgSurface

        Layout.fillWidth: true
        Layout.topMargin: first ? 0 : -6
        implicitHeight: 60 + (open ? 52 : 0)
        topLeftRadius: first ? Style.rXl : Style.rXs
        topRightRadius: first ? Style.rXl : Style.rXs
        bottomLeftRadius: last ? Style.rXl : Style.rXs
        bottomRightRadius: last ? Style.rXl : Style.rXs
        color: device.connected ? Colours.alpha(Colours.primaryContainer, 0.9) : Colours.alpha(Colours.surfaceContainerHighest, 0.6)
        clip: true

        Behavior on implicitHeight {
            SpringDefault {}
        }

        Behavior on color {
            ColorEase {}
        }

        StateLayer {
            anchors.fill: undefined
            width: parent.width
            height: 60
            topLeftRadius: row.topLeftRadius
            topRightRadius: row.topRightRadius
            bottomLeftRadius: row.open ? Style.rXs : row.bottomLeftRadius
            bottomRightRadius: row.open ? Style.rXs : row.bottomRightRadius
            tint: row.fg
            onClicked: row.device.paired ? Bt.toggle(row.device) : Bt.pair(row.device)
        }

        RowLayout {
            x: 12
            width: parent.width - 20
            height: 60
            spacing: 12

            Item {
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40

                ExprShape {
                    anchors.fill: parent
                    shape: row.device.connected ? "cookie9" : row.failed ? "puffy" : "circle"
                    color: row.device.connected ? Colours.primary : row.failed ? Colours.errorContainer : Colours.alpha(Colours.secondaryContainer, 0.9)
                    segments: 96
                }

                Icon {
                    anchors.centerIn: parent
                    name: Bt.icon(row.device.icon)
                    fill: row.device.connected ? 1 : 0
                    size: 20
                    color: row.device.connected ? Colours.fgPrimary : row.failed ? Colours.fgErrorContainer : Colours.fgSecondaryContainer
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Txt {
                    Layout.fillWidth: true
                    text: row.device.name
                    role: "bodyL"
                    color: row.fg
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Txt {
                        text: Bt.status(row.device)
                        role: "bodyS"
                        color: row.failed ? Colours.error : row.fg
                        opacity: row.failed ? 1 : 0.8
                    }

                    WavyLine {
                        Layout.preferredWidth: 44
                        Layout.preferredHeight: 10
                        visible: row.device.connected && row.device.batteryAvailable
                        value: row.device.battery
                        animating: false
                        amplitude: 1.5
                        wavelength: 10
                        thickness: 2.5
                        color: row.device.battery < 0.2 ? Colours.error : Colours.primary
                        trackColor: Colours.alpha(row.fg, 0.2)
                    }
                }
            }

            LoadingIndicator {
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                visible: row.busy
            }

            IconButton {
                visible: row.device.paired && !row.busy
                icon: row.open ? "expand_less" : "more_vert"
                size: 36
                iconColor: row.fg
                onClicked: root.expanded = row.open ? "" : row.device.address
            }
        }

        RowLayout {
            visible: row.open
            x: 12
            y: 60
            width: parent.width - 24
            height: 44
            spacing: 8

            Item {
                Layout.fillWidth: true
            }

            PillButton {
                text: row.device.connected ? "disconnect" : "connect"
                icon: row.device.connected ? "link_off" : "link"
                variant: "tonal"
                size: 36
                onClicked: Bt.toggle(row.device)
            }

            PillButton {
                text: "forget"
                icon: "delete"
                variant: "danger"
                size: 36
                onClicked: {
                    root.expanded = "";
                    Bt.forget(row.device);
                }
            }
        }
    }
}
