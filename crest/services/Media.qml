pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import qs.config

Singleton {
    id: root

    readonly property bool demo: Config.demo
    readonly property var playerModel: demo ? null : Mpris.players
    readonly property var players: playerModel ? playerModel.values : []
    property MprisPlayer manual: null
    readonly property MprisPlayer player: {
        if (manual && players.indexOf(manual) >= 0)
            return manual;
        return players.find(p => p.isPlaying) ?? players[0] ?? null;
    }
    readonly property bool available: demo || player !== null
    readonly property bool playing: demo ? true : (player?.isPlaying ?? false)
    readonly property string title: demo ? "Kōtuku" : (player?.trackTitle || "")
    readonly property string artist: demo ? "Lake Manapōuri Sound" : (player?.trackArtist || "")
    readonly property string art: demo ? "" : (player?.trackArtUrl || "")
    readonly property string identity: demo ? "Spotify" : (player?.identity || "")
    readonly property real length: demo ? 214 : (player?.length ?? 0)
    property real demoPosition: 87
    readonly property real position: demo ? demoPosition : (player?.position ?? 0)
    readonly property real progress: length > 0 ? Math.max(0, Math.min(1, position / length)) : 0
    property bool tracking: false

    function toggle(): void {
        if (player?.canTogglePlaying)
            player.togglePlaying();
    }

    function next(): void {
        if (player?.canGoNext)
            player.next();
    }

    function previous(): void {
        if (player?.canGoPrevious)
            player.previous();
    }

    function stop(): void {
        player?.stop();
    }

    function seek(fraction: real): void {
        if (player?.canSeek && player.positionSupported)
            player.position = fraction * length;
    }

    function fmt(seconds: real): string {
        const s = Math.max(0, Math.floor(seconds));
        return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, "0")}`;
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.tracking && root.playing && !root.demo
        onTriggered: root.player?.positionChanged()
    }
}
