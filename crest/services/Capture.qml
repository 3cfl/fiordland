pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.config
import qs.theme

Singleton {
    id: root

    property bool recording: false
    property bool selecting: false
    property real startedAt: 0
    property real elapsed: 0
    property string pending: ""
    property string pendingKind: ""
    property bool canRecord: Config.demo
    readonly property bool busy: selecting || shooter.running || recorder.running

    readonly property string common: `
pick() {
  base=$(xdg-user-dir "$1" 2>/dev/null)
  if [ -z "$base" ] || [ "$base" = "$HOME" ]; then base=$HOME/$2; fi
  mkdir -p "$base/$3" && printf '%s' "$base/$3"
}
choose() {
  case $mode in
    region) timeout 60 slurp -d -b "$dim" -c "$accent" -s "$fill" -w 2 </dev/null ;;
    window) printf '%s\\n' "$boxes" | timeout 60 slurp -r -b "$dim" -c "$accent" -s "$fill" -w 2 ;;
  esac
}
uri() { printf 'file://%s\\n' "$1" | sed 's/ /%20/g'; }
`

    function slurpColours(): var {
        const h = c => Math.round(c * 255).toString(16).padStart(2, "0");
        const p = Colours.primary;
        return [`#000000${h(0.35)}`, `#${h(p.r)}${h(p.g)}${h(p.b)}ff`, `#${h(p.r)}${h(p.g)}${h(p.b)}22`];
    }

    function shot(mode: string): void {
        if (Config.demo || busy || ["region", "window", "screen"].indexOf(mode) < 0)
            return;
        pending = mode;
        pendingKind = "shot";
        selecting = true;
        if (Panels.capture)
            Panels.close();
        boxer.running = true;
    }

    function record(mode: string): void {
        if (Config.demo)
            return;
        if (recording) {
            stop();
            return;
        }
        if (busy || ["region", "window", "screen"].indexOf(mode) < 0)
            return;
        pending = mode;
        pendingKind = "record";
        selecting = true;
        Panels.close();
        boxer.running = true;
    }

    function stop(): void {
        if (recorder.running)
            recorder.signal(2);
    }

    function launch(boxes: string): void {
        const [dim, accent, fill] = slurpColours();
        const output = Hyprland.focusedMonitor?.name ?? "";
        const env = ["env", `mode=${pending}`, `out=${output}`, `boxes=${boxes}`, `dim=${dim}`, `accent=${accent}`, `fill=${fill}`];
        if (pendingKind === "shot") {
            shooter.command = env.concat(["sh", "-c", root.common + `
dir=$(pick PICTURES Pictures Screenshots) || exit 1
file=$dir/$(date +%Y-%m-%d_%H-%M-%S).png
if [ "$mode" = screen ]; then
  sleep 0.25
  if [ -n "$out" ]; then grim -o "$out" "$file"; else grim "$file"; fi || exit 1
else
  g=$(choose) || exit 2
  [ -n "$g" ] || exit 2
  sleep 0.05
  grim -g "$g" "$file" || exit 1
fi
wl-copy --type image/png < "$file"
echo "$file"
(
  a=$(timeout 600 notify-send -a Screenshot -i "$file" -h "string:image-path:$file" -A open=Open -A folder="Show folder" "Screenshot copied" "Saved to $(basename "$dir")/$(basename "$file")")
  case $a in open) xdg-open "$file" ;; folder) xdg-open "$dir" ;; esac
) >/dev/null 2>&1 &
`]);
            shooter.running = true;
        } else {
            recorder.command = env.concat([`audio=${Config.capture.audio ? 1 : 0}`, "sh", "-c", root.common + `
dir=$(pick VIDEOS Videos Recordings) || exit 1
file=$dir/$(date +%Y-%m-%d_%H-%M-%S).mp4
if [ "$mode" = screen ]; then
  set -- -o "$out"
  [ -n "$out" ] || set --
else
  g=$(choose) || exit 2
  [ -n "$g" ] || exit 2
  set -- -g "$g"
fi
if [ "$audio" = 1 ] && command -v pactl >/dev/null; then
  sink=$(pactl get-default-sink 2>/dev/null)
  [ -n "$sink" ] && set -- "$@" "--audio=$sink.monitor"
fi
pid=
stopped=
trap 'stopped=1; [ -n "$pid" ] && kill -INT "$pid" 2>/dev/null' INT TERM
run() {
  wf-recorder -y -f "$file" "$@" </dev/null >/dev/null 2>&1 &
  pid=$!
  rc=0
  wait "$pid" || rc=$?
  while kill -0 "$pid" 2>/dev/null; do wait "$pid" || rc=$?; done
  pid=
  return $rc
}
echo "recording"
started=$(date +%s)
node=
for n in /dev/dri/renderD*; do [ -e "$n" ] && { node=$n; break; }; done
if [ -n "$node" ]; then
  run "$@" -c h264_vaapi -d "$node"
  if [ -z "$stopped" ] && [ $(( $(date +%s) - started )) -lt 3 ]; then
    rm -f "$file"
    run "$@"
  fi
else
  run "$@"
fi
[ -s "$file" ] || exit 1
uri "$file" | wl-copy --type text/uri-list
echo "$file"
(
  a=$(timeout 600 notify-send -a "Screen recording" -i video-x-generic -A open=Open -A folder="Show folder" "Recording copied" "Saved to $(basename "$dir")/$(basename "$file")")
  case $a in open) xdg-open "$file" ;; folder) xdg-open "$dir" ;; esac
) >/dev/null 2>&1 &
`]);
            recorder.running = true;
        }
    }

    function windowBoxes(text: string): string {
        const split = text.indexOf("\n---\n");
        if (split < 0)
            return "";
        try {
            const monitors = JSON.parse(text.slice(0, split));
            const clients = JSON.parse(text.slice(split + 5));
            const visible = monitors.map(m => m.activeWorkspace?.id).concat(monitors.map(m => m.specialWorkspace?.id)).filter(id => id !== undefined && id !== 0);
            return clients.filter(c => c.mapped && !c.hidden && visible.indexOf(c.workspace?.id) >= 0 && c.size?.[0] > 0).map(c => `${c.at[0]},${c.at[1]} ${c.size[0]}x${c.size[1]}`).join("\n");
        } catch (e) {
            return "";
        }
    }

    Process {
        running: !Config.demo
        command: ["sh", "-c", "command -v wf-recorder >/dev/null"]
        onExited: code => root.canRecord = code === 0
    }

    Process {
        id: boxer

        command: ["sh", "-c", "hyprctl -j monitors; printf '\\n---\\n'; hyprctl -j clients"]
        stdout: StdioCollector {
            onStreamFinished: delay.boxes = root.pending === "window" ? root.windowBoxes(text) : ""
        }
        onExited: delay.restart()
    }

    Timer {
        id: delay

        property string boxes: ""

        interval: 220
        onTriggered: root.launch(boxes)
    }

    Process {
        id: shooter

        onExited: root.selecting = false
    }

    Process {
        id: recorder

        stdout: SplitParser {
            onRead: line => {
                if (line === "recording") {
                    root.selecting = false;
                    root.recording = true;
                    root.startedAt = Date.now();
                    root.elapsed = 0;
                }
            }
        }
        onExited: {
            root.selecting = false;
            root.recording = false;
        }
    }

    Timer {
        running: root.recording
        interval: 500
        repeat: true
        onTriggered: root.elapsed = (Date.now() - root.startedAt) / 1000
    }
}
