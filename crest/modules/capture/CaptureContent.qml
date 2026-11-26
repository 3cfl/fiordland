pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.components
import qs.config
import qs.services
import qs.theme

Glass {
    id: root

    property string kind: "shot"
    readonly property var modes: [
        { id: "region", icon: "crop_free", label: "region", key: "1" },
        { id: "window", icon: "select_window", label: "window", key: "2" },
        { id: "screen", icon: "fullscreen", label: "screen", key: "3" }
    ]

    signal done

    implicitWidth: row.implicitWidth + 24
    implicitHeight: row.implicitHeight + 24
    radius: Style.rXxl
    focus: true

    Component.onCompleted: forceActiveFocus()

    function go(mode: string): void {
        Config.capture.mode = mode;
        if (kind === "shot")
            Capture.shot(mode);
        else
            Capture.record(mode);
    }

    Keys.onPressed: event => {
        const i = ["1", "2", "3"].indexOf(event.text);
        if (i >= 0) {
            go(modes[i].id);
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            go(Config.capture.mode);
        } else if (event.key === Qt.Key_Tab) {
            if (Capture.canRecord)
                kind = kind === "shot" ? "record" : "shot";
        } else if (event.key === Qt.Key_Escape) {
            done();
        } else {
            return;
        }
        event.accepted = true;
    }

    RowLayout {
        id: row

        x: 12
        y: 12
        spacing: 12

        Segmented {
            size: 56
            options: [
                { id: "shot", icon: "photo_camera", label: "" },
                { id: "record", icon: "videocam", label: "" }
            ]
            current: root.kind
            onPicked: id => {
                if (id === "shot" || Capture.canRecord)
                    root.kind = id;
            }
        }

        Rectangle {
            Layout.preferredWidth: 1
            Layout.preferredHeight: 32
            color: Colours.outlineVariant
        }

        Repeater {
            model: root.modes

            Rectangle {
                id: btn

                required property var modelData
                readonly property bool preferred: Config.capture.mode === modelData.id

                Layout.preferredHeight: 56
                Layout.preferredWidth: inner.implicitWidth + 36
                radius: area.pressed ? Style.rMd : preferred ? Style.rLg : 28
                color: preferred ? (root.kind === "record" ? Colours.errorContainer : Colours.primaryContainer) : Colours.alpha(Colours.surfaceContainerHighest, 0.7)

                Behavior on radius {
                    SpringFast {}
                }

                Behavior on color {
                    ColorEase {}
                }

                Row {
                    id: inner

                    anchors.centerIn: parent
                    spacing: 8

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: btn.modelData.icon
                        size: 22
                        fill: btn.preferred ? 1 : 0
                        color: btn.preferred ? (root.kind === "record" ? Colours.fgErrorContainer : Colours.fgPrimaryContainer) : Colours.fgSurface
                    }

                    Txt {
                        anchors.verticalCenter: parent.verticalCenter
                        text: btn.modelData.label
                        role: "labelL"
                        emphasis: btn.preferred
                        color: btn.preferred ? (root.kind === "record" ? Colours.fgErrorContainer : Colours.fgPrimaryContainer) : Colours.fgSurface
                        elide: Text.ElideNone
                    }
                }

                StateLayer {
                    id: area

                    radius: btn.radius
                    tint: Colours.fgSurface
                    onClicked: root.go(btn.modelData.id)
                }
            }
        }

        Rectangle {
            Layout.preferredWidth: 1
            Layout.preferredHeight: 32
            color: Colours.outlineVariant
        }

        IconButton {
            visible: root.kind === "record"
            size: 48
            icon: Config.capture.audio ? "volume_up" : "volume_off"
            checkable: true
            checked: Config.capture.audio
            onClicked: Config.capture.audio = !Config.capture.audio
        }

        IconButton {
            size: 48
            icon: "folder_open"
            variant: "tonal"
            onClicked: {
                Quickshell.execDetached(["sh", "-c", root.kind === "shot" ? 'd=$(xdg-user-dir PICTURES 2>/dev/null); [ -n "$d" ] && [ "$d" != "$HOME" ] || d=$HOME/Pictures; mkdir -p "$d/Screenshots" && xdg-open "$d/Screenshots"' : 'd=$(xdg-user-dir VIDEOS 2>/dev/null); [ -n "$d" ] && [ "$d" != "$HOME" ] || d=$HOME/Videos; mkdir -p "$d/Recordings" && xdg-open "$d/Recordings"']);
                root.done();
            }
        }
    }
}
