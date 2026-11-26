pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell.Services.Mpris
import qs.components
import qs.config
import qs.services
import qs.theme

Item {
    id: root

    readonly property var player: Media.player
    readonly property bool hasArt: art.status === Image.Ready
    readonly property string album: Config.demo ? "Southern Lakes" : (player?.trackAlbum ?? "")
    readonly property bool canShuffle: player?.shuffleSupported ?? false
    readonly property bool canLoop: player?.loopSupported ?? false
    readonly property int loop: player?.loopState ?? MprisLoopState.None
    readonly property bool lyricsOn: Config.media.lyrics && Config.media.showLyrics && Media.available
    readonly property var musicApps: Apps.entries.filter(e => {
        const c = e.categories ?? [];
        return c.indexOf("Music") >= 0 || (c.indexOf("Audio") >= 0 && c.indexOf("Player") >= 0);
    }).slice(0, 4)

    implicitHeight: Media.available ? 312 + (lyricsOn ? 248 : 0) : 312

    Component.onCompleted: {
        Media.trackers++;
        Lyrics.acquire();
    }
    Component.onDestruction: {
        Media.trackers--;
        Lyrics.release();
    }

    Hold {
        active: Media.available && Media.playing && root.visible
        onAcquire: Cava.acquire()
        onRelease: Cava.release()
    }

    Rectangle {
        anchors.fill: parent
        radius: Style.rLgInc
        color: Colours.alpha(Colours.surfaceContainerHighest, 0.5)
        clip: true

        Image {
            id: art

            anchors.fill: parent
            source: Media.art
            sourceSize.width: 400
            sourceSize.height: 400
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: false
        }

        MultiEffect {
            anchors.fill: parent
            visible: root.hasArt && Style.effects && Media.available
            source: art
            blurEnabled: true
            blur: 1
            blurMax: 64
            saturation: 0.4
            opacity: 0.45
        }

        Rectangle {
            anchors.fill: parent
            visible: root.hasArt && Media.available
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop {
                    position: 0
                    color: Colours.alpha(Colours.surfaceContainer, 0.05)
                }
                GradientStop {
                    position: 0.55
                    color: Colours.alpha(Colours.surfaceContainer, 0.55)
                }
            }
        }
    }

    Item {
        id: disc

        x: 16
        y: 16
        width: 280
        height: 280

        readonly property real coverSize: 196
        readonly property real inner: coverSize / 2 + 8
        readonly property int count: 72
        readonly property var levels: {
            const v = Cava.values;
            const n = count / 2;
            const out = [];
            for (let i = 0; i < n; i++) {
                const k = v.length > 0 ? v[Math.floor(i / n * v.length)] : 0;
                out.push(k);
            }
            return out;
        }
        property real idlePhase: 0

        FrameAnimation {
            running: Media.playing && Cava.values.length === 0 && root.visible && !Motion.reduced
            onTriggered: disc.idlePhase = (disc.idlePhase + frameTime * 1.6) % (Math.PI * 200)
        }

        Repeater {
            model: disc.count

            Rectangle {
                id: bar

                required property int index
                readonly property int half: disc.count / 2
                readonly property int slot: index < half ? index : disc.count - 1 - index
                readonly property real level: {
                    if (!Media.available || !Media.playing)
                        return 0;
                    if (Cava.values.length > 0)
                        return disc.levels[slot] ?? 0;
                    const t = disc.idlePhase;
                    const beat = Math.pow(Math.max(0, Math.sin(t * 2.6)), 6);
                    const w = 0.5 + 0.5 * Math.sin(t * 1.3 + slot * 0.5) * Math.sin(t * 0.7 - slot * 0.23);
                    const fall = 1 - slot / half * 0.55;
                    return Math.min(1, (0.1 + 0.45 * w * w + 0.35 * beat) * fall);
                }
                readonly property real angle: (index + 0.5) / disc.count * 360

                x: disc.width / 2 - width / 2
                y: disc.height / 2 - disc.inner - height
                width: 4
                height: 4 + level * 34
                radius: 2
                color: Colours.primary
                opacity: Media.available ? 0.45 + level * 0.55 : 0.25
                transform: Rotation {
                    origin.x: bar.width / 2
                    origin.y: bar.height + disc.inner
                    angle: bar.angle
                }

                Behavior on height {
                    enabled: Cava.values.length === 0
                    SpringFast {}
                }
            }
        }

        Rectangle {
            anchors.centerIn: parent
            width: disc.coverSize
            height: disc.coverSize
            radius: width / 2
            color: Colours.tertiaryContainer
            visible: !root.hasArt || !Media.available

            Repeater {
                model: 3

                Rectangle {
                    required property int index

                    anchors.centerIn: parent
                    width: parent.width * (0.82 - index * 0.18)
                    height: width
                    radius: width / 2
                    color: "transparent"
                    border.width: 1
                    border.color: Colours.alpha(Colours.fgTertiaryContainer, 0.12)
                }
            }

            Rectangle {
                anchors.centerIn: parent
                width: 64
                height: 64
                radius: 32
                color: Colours.alpha(Colours.fgTertiaryContainer, 0.12)

                Icon {
                    anchors.centerIn: parent
                    name: Media.available ? "music_note" : "music_off"
                    size: 30
                    fill: 1
                    color: Colours.fgTertiaryContainer
                }
            }

            RotationAnimator on rotation {
                running: Media.playing && root.visible && !Motion.reduced
                from: 0
                to: 360
                duration: 20000
                loops: Animation.Infinite
            }
        }

        Item {
            id: mask

            anchors.centerIn: parent
            width: disc.coverSize
            height: disc.coverSize
            visible: false
            layer.enabled: true

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: "white"
            }
        }

        MultiEffect {
            anchors.centerIn: parent
            width: disc.coverSize
            height: disc.coverSize
            visible: root.hasArt && Media.available
            source: art
            maskEnabled: true
            maskSource: mask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1
            scale: Media.playing ? 1 : 0.94

            Behavior on scale {
                SpringDefault {}
            }
        }
    }

    ColumnLayout {
        x: disc.x + disc.width + 12
        y: 24
        width: parent.width - x - 24
        height: 264
        visible: !Media.available
        spacing: 6

        Item {
            Layout.fillHeight: true
        }

        Txt {
            text: "nothing playing"
            role: "headlineS"
        }

        Txt {
            Layout.fillWidth: true
            text: "start some music and it'll show up here with lyrics and a live visualizer"
            role: "bodyM"
            color: Colours.fgSurfaceVariant
            wrapMode: Text.Wrap
        }

        Flow {
            Layout.fillWidth: true
            Layout.topMargin: 12
            visible: root.musicApps.length > 0
            spacing: 8

            Repeater {
                model: root.musicApps

                PillButton {
                    required property var modelData

                    size: 40
                    variant: "tonal"
                    icon: "play_arrow"
                    text: modelData.name.toLowerCase()
                    onClicked: Apps.launch(modelData)
                }
            }
        }

        Item {
            Layout.fillHeight: true
        }
    }

    ColumnLayout {
        x: disc.x + disc.width + 12
        y: 22
        width: parent.width - x - 22
        height: 272
        visible: Media.available
        spacing: 2

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                Layout.preferredHeight: 28
                Layout.preferredWidth: playerRow.implicitWidth + 20
                radius: 14
                color: Colours.alpha(Colours.surfaceContainerHighest, 0.8)

                Row {
                    id: playerRow

                    anchors.centerIn: parent
                    spacing: 6

                    Txt {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Media.identity.toLowerCase() || "player"
                        role: "labelM"
                        color: Colours.fgSurface
                        elide: Text.ElideNone
                    }

                    Icon {
                        visible: Media.players.length > 1
                        name: "unfold_more"
                        size: 16
                        color: Colours.fgSurfaceVariant
                    }
                }

                StateLayer {
                    radius: 14
                    enabled: Media.players.length > 1
                    onClicked: {
                        const list = Media.players;
                        const i = list.indexOf(Media.player);
                        Media.manual = list[(i + 1) % list.length];
                    }
                }
            }

            Item {
                Layout.fillWidth: true
            }

            IconButton {
                visible: Config.media.lyrics
                size: 32
                iconSize: 18
                icon: "lyrics"
                checkable: true
                checked: Config.media.showLyrics
                onClicked: Config.media.showLyrics = !Config.media.showLyrics
            }
        }

        Item {
            Layout.preferredHeight: 10
        }

        Txt {
            Layout.fillWidth: true
            text: Media.title || "unknown track"
            role: "headlineS"
            wrapMode: Text.Wrap
            maximumLineCount: 2
        }

        Txt {
            Layout.fillWidth: true
            visible: text !== ""
            text: [Media.artist, root.album].filter(s => s).join("  ·  ")
            role: "bodyL"
            color: Colours.fgSurfaceVariant
        }

        Item {
            Layout.fillHeight: true
        }

        WavyLine {
            Layout.fillWidth: true
            implicitHeight: 20
            value: Media.progress
            animating: Media.playing
            amplitude: Media.playing ? 3 : 0
            wavelength: 32
            thickness: 5
            trackColor: Colours.alpha(Colours.fgSurface, 0.16)

            Behavior on amplitude {
                SpringDefault {}
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: mouse => Media.seek(mouse.x / width)
            }
        }

        RowLayout {
            Layout.fillWidth: true

            Txt {
                text: Media.fmt(Media.position)
                role: "labelM"
                color: Colours.fgSurfaceVariant
                elide: Text.ElideNone
            }

            Item {
                Layout.fillWidth: true
            }

            Txt {
                text: Media.length > 0 ? Media.fmt(Media.length) : "live"
                role: "labelM"
                color: Colours.fgSurfaceVariant
                elide: Text.ElideNone
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 6
            spacing: 8

            IconButton {
                size: 40
                icon: "shuffle"
                checkable: true
                checked: root.player?.shuffle ?? false
                enabled: root.canShuffle
                opacity: enabled ? 1 : 0.38
                onClicked: root.player.shuffle = !root.player.shuffle
            }

            Item {
                Layout.fillWidth: true
            }

            IconButton {
                size: 48
                variant: "tonal"
                icon: "skip_previous"
                enabled: root.player?.canGoPrevious ?? Config.demo
                onClicked: Media.previous()
            }

            Item {
                Layout.preferredWidth: 84
                Layout.preferredHeight: 60

                Rectangle {
                    id: play

                    anchors.centerIn: parent
                    width: playArea.pressed ? 78 : 84
                    height: 60
                    radius: playArea.pressed ? Style.rMd : (Media.playing ? Style.rLgInc : 30)
                    color: Colours.primary

                    Behavior on radius {
                        SpringFast {}
                    }

                    Behavior on width {
                        SpringFast {}
                    }

                    Icon {
                        anchors.centerIn: parent
                        name: Media.playing ? "pause" : "play_arrow"
                        size: 32
                        fill: 1
                        color: Colours.fgPrimary
                    }

                    StateLayer {
                        id: playArea

                        radius: play.radius
                        tint: Colours.fgPrimary
                        onClicked: Media.toggle()
                    }
                }
            }

            IconButton {
                size: 48
                variant: "tonal"
                icon: "skip_next"
                enabled: root.player?.canGoNext ?? Config.demo
                onClicked: Media.next()
            }

            Item {
                Layout.fillWidth: true
            }

            IconButton {
                size: 40
                icon: root.loop === MprisLoopState.Track ? "repeat_one" : "repeat"
                checkable: true
                checked: root.loop !== MprisLoopState.None
                enabled: root.canLoop
                opacity: enabled ? 1 : 0.38
                onClicked: root.player.loopState = root.loop === MprisLoopState.None ? MprisLoopState.Playlist : root.loop === MprisLoopState.Playlist ? MprisLoopState.Track : MprisLoopState.None
            }
        }
    }

    LyricsView {
        x: 20
        y: 312
        width: parent.width - 40
        height: parent.height - y - 16
        visible: root.lyricsOn
    }
}
