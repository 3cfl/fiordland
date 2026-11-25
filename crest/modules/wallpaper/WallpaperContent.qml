pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.components
import qs.config
import qs.services
import qs.theme

Glass {
    id: root

    readonly property var variants: [
        { id: "scheme-tonal-spot", label: "calm" },
        { id: "scheme-expressive", label: "expressive" },
        { id: "scheme-vibrant", label: "vibrant" },
        { id: "scheme-content", label: "true to image" },
        { id: "scheme-neutral", label: "neutral" }
    ]

    signal done

    implicitWidth: 1000
    implicitHeight: column.implicitHeight + 40
    radius: Style.rXxl

    Component.onCompleted: Wallpapers.scan()

    Keys.onEscapePressed: done()

    ColumnLayout {
        id: column

        x: 20
        y: 20
        width: parent.width - 40
        spacing: 16

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 8
            spacing: 8

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Txt {
                    text: "wallpaper and colours"
                    role: "titleL"
                }

                Txt {
                    text: Scheme.generating ? "picking colours…" : (Scheme.fromWallpaper ? "colours follow your wallpaper" : "fiordland colours")
                    role: "bodyM"
                    color: Colours.fgSurfaceVariant
                }
            }

            Segmented {
                options: [{ id: "dark", icon: "dark_mode" }, { id: "light", icon: "light_mode" }]
                current: Config.appearance.mode === "light" ? "light" : "dark"
                onPicked: id => Config.appearance.mode = id
            }
        }

        ListView {
            id: list

            Layout.fillWidth: true
            Layout.preferredHeight: 196
            orientation: ListView.Horizontal
            spacing: 12
            clip: true
            model: Wallpapers.all
            cacheBuffer: 0
            boundsBehavior: Flickable.StopAtBounds
            currentIndex: Math.max(0, Wallpapers.all.indexOf(Wallpapers.current))

            delegate: Item {
                id: thumb

                required property string modelData
                required property int index
                readonly property bool selected: modelData === Wallpapers.current

                width: 300
                height: 196

                Rectangle {
                    id: frame

                    anchors.fill: parent
                    anchors.margins: thumb.selected ? 0 : 6
                    radius: thumb.selected ? Style.rXxl : Style.rXl
                    color: Colours.surfaceContainerHighest
                    clip: true

                    Behavior on anchors.margins {
                        SpringFast {}
                    }

                    Behavior on radius {
                        SpringFast {}
                    }

                    Image {
                        anchors.fill: parent
                        source: "file://" + thumb.modelData
                        sourceSize.width: 320
                        sourceSize.height: 200
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: false
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: "transparent"
                        border.width: thumb.selected ? 4 : 0
                        border.color: Colours.primary
                    }

                    StateLayer {
                        radius: frame.radius
                        tint: "white"
                        onClicked: Wallpapers.set(thumb.modelData)
                    }
                }

                Item {
                    visible: thumb.selected
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 12
                    width: 36
                    height: 36

                    ExprShape {
                        anchors.fill: parent
                        shape: "cookie9"
                        color: Colours.primary
                    }

                    Icon {
                        anchors.centerIn: parent
                        name: "check"
                        size: 20
                        color: Colours.fgPrimary
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 8
            spacing: 8

            Txt {
                text: "style"
                role: "labelL"
                color: Colours.fgSurfaceVariant
            }

            Repeater {
                model: root.variants

                Rectangle {
                    id: chip

                    required property var modelData
                    readonly property bool selected: Config.appearance.variant === modelData.id

                    implicitWidth: chipText.implicitWidth + (selected ? 44 : 28)
                    implicitHeight: 36
                    radius: selected ? height / 2 : Style.rMd
                    color: selected ? Colours.secondaryContainer : "transparent"
                    border.width: selected ? 0 : 1
                    border.color: Colours.outlineVariant

                    Behavior on radius {
                        SpringFast {}
                    }

                    Behavior on implicitWidth {
                        SpringFast {}
                    }

                    Icon {
                        visible: chip.selected
                        anchors.verticalCenter: parent.verticalCenter
                        x: 12
                        name: "check"
                        size: 18
                        color: Colours.fgSecondaryContainer
                    }

                    Txt {
                        id: chipText

                        anchors.verticalCenter: parent.verticalCenter
                        x: chip.selected ? 32 : 14
                        text: chip.modelData.label
                        role: "labelL"
                        color: chip.selected ? Colours.fgSecondaryContainer : Colours.fgSurfaceVariant
                    }

                    StateLayer {
                        radius: chip.radius
                        onClicked: {
                            Config.appearance.variant = chip.modelData.id;
                            Config.appearance.scheme = "wallpaper";
                        }
                    }
                }
            }

            Item {
                Layout.fillWidth: true
            }

            PillButton {
                variant: Config.appearance.scheme === "wallpaper" ? "outlined" : "tonal"
                icon: "water"
                text: "fiordland colours"
                onClicked: Config.appearance.scheme = Config.appearance.scheme === "wallpaper" ? "fiordland" : "wallpaper"
            }
        }
    }
}
