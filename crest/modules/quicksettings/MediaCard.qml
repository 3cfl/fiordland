import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import qs.components
import qs.services
import qs.theme

Rectangle {
    id: root

    implicitHeight: 132
    radius: Style.rXl
    color: Colours.alpha(Colours.surfaceContainerHighest, 0.7)
    clip: true

    Component.onCompleted: Media.tracking = true
    Component.onDestruction: Media.tracking = false

    Image {
        id: art

        anchors.fill: parent
        source: Media.art
        sourceSize.width: 128
        sourceSize.height: 128
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        visible: false
    }

    MultiEffect {
        anchors.fill: parent
        visible: art.status === Image.Ready && Style.blur
        source: art
        blurEnabled: true
        blur: 1
        blurMax: 48
        saturation: 0.2
        opacity: 0.35
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 14

        Item {
            Layout.preferredWidth: 104
            Layout.preferredHeight: 104

            ExprShape {
                anchors.fill: parent
                shape: "cookie9"
                color: Colours.tertiaryContainer
                visible: art.status !== Image.Ready
            }

            Icon {
                anchors.centerIn: parent
                visible: art.status !== Image.Ready
                name: "music_note"
                size: 40
                fill: 1
                color: Colours.onTertiaryContainer
            }

            Rectangle {
                id: artFrame

                anchors.fill: parent
                radius: Style.rLgInc
                visible: false
                layer.enabled: true
            }

            MultiEffect {
                anchors.fill: parent
                visible: art.status === Image.Ready
                source: art
                maskEnabled: true
                maskSource: artFrame
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 2

            Txt {
                Layout.fillWidth: true
                text: Media.identity.toLowerCase()
                role: "labelS"
                color: Colours.primary
            }

            Txt {
                Layout.fillWidth: true
                text: Media.title || "nothing playing"
                role: "titleM"
            }

            Txt {
                Layout.fillWidth: true
                text: Media.artist
                role: "bodyM"
                color: Colours.onSurfaceVariant
            }

            Item {
                Layout.fillHeight: true
            }

            WavyLine {
                Layout.fillWidth: true
                value: Media.progress
                animating: Media.playing
                amplitude: Media.playing ? 2.5 : 0
                trackColor: Colours.alpha(Colours.onSurface, 0.16)

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: mouse => Media.seek(mouse.x / width)
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 4

                Txt {
                    text: `${Media.fmt(Media.position)} / ${Media.fmt(Media.length)}`
                    role: "labelS"
                    color: Colours.onSurfaceVariant
                    elide: Text.ElideNone
                }

                Item {
                    Layout.fillWidth: true
                }

                IconButton {
                    size: 32
                    icon: "skip_previous"
                    onClicked: Media.previous()
                }

                IconButton {
                    size: 40
                    wide: true
                    variant: "filled"
                    icon: Media.playing ? "pause" : "play_arrow"
                    onClicked: Media.toggle()
                }

                IconButton {
                    size: 32
                    icon: "skip_next"
                    onClicked: Media.next()
                }
            }
        }
    }
}
