import QtQuick
import QtMultimedia

Item {
    id: root

    property url source
    property bool running: true
    property bool ready: false

    MediaPlayer {
        id: player

        source: root.source
        loops: MediaPlayer.Infinite
        videoOutput: output
        onPositionChanged: if (position > 0) root.ready = true
        onErrorOccurred: root.ready = false
        Component.onCompleted: if (root.running) play()
    }

    Connections {
        target: root

        function onRunningChanged(): void {
            if (root.running)
                player.play();
            else
                player.pause();
        }
    }

    VideoOutput {
        id: output

        anchors.fill: parent
        fillMode: VideoOutput.PreserveAspectCrop
        opacity: root.ready ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: 700
            }
        }
    }
}
