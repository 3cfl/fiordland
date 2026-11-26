pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.components
import qs.services
import qs.theme

Item {
    id: root

    readonly property bool synced: Lyrics.lines.length > 0
    readonly property bool hasPlain: !synced && Lyrics.plain !== "" && Lyrics.status === "ready"
    property bool userScrolled: false

    clip: true

    Rectangle {
        anchors.fill: parent
        radius: Style.rLg
        color: Colours.alpha(Colours.surfaceContainerLowest, 0.35)
    }

    Timer {
        id: resume

        interval: 3500
        onTriggered: root.userScrolled = false
    }

    ListView {
        id: list

        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        visible: root.synced
        model: Lyrics.lines
        currentIndex: Math.max(0, Lyrics.current)
        spacing: 4
        boundsBehavior: Flickable.StopAtBounds
        highlightRangeMode: root.userScrolled ? ListView.NoHighlightRange : ListView.ApplyRange
        preferredHighlightBegin: height / 2 - 22
        preferredHighlightEnd: height / 2 + 22
        highlightMoveDuration: Motion.reduced ? 0 : 450
        highlightMoveVelocity: -1
        header: Item {
            height: list.height / 2 - 22
        }
        footer: Item {
            height: list.height / 2 - 22
        }

        onMovementStarted: {
            root.userScrolled = true;
            resume.stop();
        }
        onMovementEnded: resume.restart()

        delegate: Item {
            id: line

            required property var modelData
            required property int index
            readonly property bool now: index === Lyrics.current
            readonly property bool past: index < Lyrics.current

            width: list.width
            height: body.implicitHeight + 10

            Txt {
                id: body

                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: line.modelData.text || "♪"
                role: "titleM"
                emphasis: line.now
                wrapMode: Text.Wrap
                maximumLineCount: 3
                color: line.now ? Colours.primary : Colours.fgSurface
                opacity: line.now ? 1 : line.past ? 0.35 : 0.6
                scale: line.now ? 1.12 : 1
                transformOrigin: Item.Center

                Behavior on scale {
                    SpringDefault {}
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: Motion.durShort
                    }
                }

                Behavior on color {
                    ColorEase {}
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (Media.length > 0)
                        Media.seek(line.modelData.time / Media.length);
                    root.userScrolled = false;
                }
            }
        }
    }

    Flickable {
        anchors.fill: parent
        anchors.margins: 16
        visible: root.hasPlain
        contentHeight: plainText.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        Txt {
            id: plainText

            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: Lyrics.plain
            role: "bodyL"
            wrapMode: Text.Wrap
            elide: Text.ElideNone
            maximumLineCount: 100000
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        visible: !root.synced && !root.hasPlain
        spacing: 10

        LoadingIndicator {
            Layout.alignment: Qt.AlignHCenter
            visible: Lyrics.status === "loading" || Lyrics.status === "idle"
            running: visible
            color: Colours.primary
        }

        Icon {
            Layout.alignment: Qt.AlignHCenter
            visible: !(Lyrics.status === "loading" || Lyrics.status === "idle")
            name: Lyrics.status === "instrumental" ? "piano" : Lyrics.status === "offline" ? "cloud_off" : "lyrics"
            size: 32
            color: Colours.fgSurfaceVariant
        }

        Txt {
            Layout.alignment: Qt.AlignHCenter
            text: ({ loading: "finding lyrics…", idle: "finding lyrics…", instrumental: "instrumental", offline: "couldn't reach lrclib" })[Lyrics.status] ?? "no lyrics for this one"
            role: "titleS"
            color: Colours.fgSurfaceVariant
        }

        PillButton {
            Layout.alignment: Qt.AlignHCenter
            visible: Lyrics.status === "none" || Lyrics.status === "offline"
            text: "try again"
            onClicked: Lyrics.retry()
        }
    }
}
