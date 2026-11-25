pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.config

Singleton {
    id: root

    readonly property bool demo: Config.demo
    property real demoVolume: 0.62
    property bool demoMuted: false

    readonly property PwNode sink: demo ? null : Pipewire.defaultAudioSink
    readonly property PwNode source: demo ? null : Pipewire.defaultAudioSource
    readonly property bool ready: demo || (sink?.ready ?? false)
    readonly property real volume: demo ? demoVolume : (sink?.audio?.volume ?? 0)
    readonly property bool muted: demo ? demoMuted : (sink?.audio?.muted ?? false)
    readonly property bool micMuted: demo ? false : (source?.audio?.muted ?? false)
    readonly property string icon: muted || volume <= 0.001 ? "volume_off" : volume < 0.34 ? "volume_mute" : volume < 0.67 ? "volume_down" : "volume_up"
    readonly property string deviceName: demo ? "Speakers" : (sink?.description || sink?.nickname || sink?.name || "")

    signal changed

    function setVolume(v: real): void {
        const val = Math.max(0, Math.min(1, v));
        if (demo) {
            demoVolume = val;
            demoMuted = false;
        } else if (sink?.ready && sink.audio) {
            sink.audio.muted = false;
            sink.audio.volume = val;
        }
    }

    function toggleMute(): void {
        if (demo)
            demoMuted = !demoMuted;
        else if (sink?.ready && sink.audio)
            sink.audio.muted = !sink.audio.muted;
    }

    function toggleMic(): void {
        if (!demo && source?.ready && source.audio)
            source.audio.muted = !source.audio.muted;
    }

    PwObjectTracker {
        objects: [root.sink, root.source].filter(n => n)
    }

    Connections {
        target: root.sink?.audio ?? null
        ignoreUnknownSignals: true

        function onVolumeChanged(): void {
            root.changed();
        }

        function onMutedChanged(): void {
            root.changed();
        }
    }
}
