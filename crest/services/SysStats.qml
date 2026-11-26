pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

Singleton {
    id: root

    property int users: 0
    readonly property bool active: users > 0 && !Config.demo
    property bool detailed: false

    property real cpu: Config.demo ? 0.32 : 0
    property real gpu: Config.demo ? 0.18 : -1
    property real memory: Config.demo ? 0.54 : 0
    property real swap: 0
    property real memTotal: Config.demo ? 16e9 : 0
    property real memUsed: Config.demo ? 8.6e9 : 0
    property real swapTotal: 0
    property real cpuTemp: Config.demo ? 52 : -1
    property real gpuTemp: -1
    property real gpuMemUsed: -1
    property real gpuMemTotal: -1
    property real uptime: 0
    property string cpuName: Config.demo ? "Fiordland CPU" : ""
    property string gpuVendor: ""
    property var history: []
    property var disks: Config.demo ? [{ name: "system", target: "/", size: 512e9, used: 210e9, avail: 302e9 }] : []
    property var hogs: []

    property var lastCpu: null
    property real lastRc6: -1
    property real lastT: -1

    function acquire(): void {
        users++;
    }

    function release(): void {
        users = Math.max(0, users - 1);
    }

    function bytes(n: real): string {
        if (!(n >= 0))
            return "–";
        const units = ["B", "KB", "MB", "GB", "TB", "PB"];
        let i = 0;
        let v = n;
        while (v >= 1000 && i < units.length - 1) {
            v /= 1000;
            i++;
        }
        return `${v >= 100 || i === 0 ? Math.round(v) : v.toFixed(1)} ${units[i]}`;
    }

    function duration(s: real): string {
        const d = Math.floor(s / 86400);
        const h = Math.floor((s % 86400) / 3600);
        const m = Math.floor((s % 3600) / 60);
        if (d > 0)
            return `${d}d ${h}h`;
        if (h > 0)
            return `${h}h ${m}m`;
        return `${m}m`;
    }

    function parse(line: string): void {
        const f = {};
        for (const part of line.trim().split(" ")) {
            const i = part.indexOf("=");
            if (i > 0)
                f[part.slice(0, i)] = part.slice(i + 1);
        }
        const t = parseFloat(f.t);
        if (!(t > 0))
            return;
        root.uptime = t;

        const c = (f.cpu ?? "").split(",").map(Number);
        if (c.length >= 4 && c.every(n => n >= 0)) {
            const idle = c[3] + (c[4] ?? 0);
            const total = c.slice(0, 8).reduce((a, b) => a + b, 0);
            if (root.lastCpu) {
                const dt = total - root.lastCpu.total;
                const di = idle - root.lastCpu.idle;
                if (dt > 0)
                    root.cpu = Math.max(0, Math.min(1, 1 - di / dt));
            }
            root.lastCpu = { total, idle };
        }

        const m = (f.mem ?? "").split(",").map(Number);
        if (m.length === 4 && m[0] > 0) {
            root.memTotal = m[0] * 1024;
            root.memUsed = (m[0] - m[1]) * 1024;
            root.memory = Math.max(0, Math.min(1, (m[0] - m[1]) / m[0]));
            root.swapTotal = m[2] * 1024;
            root.swap = m[2] > 0 ? Math.max(0, Math.min(1, (m[2] - m[3]) / m[2])) : 0;
        }

        if (f.rc6 !== undefined) {
            const rc6 = parseFloat(f.rc6);
            if (root.lastRc6 >= 0 && root.lastT > 0 && t > root.lastT) {
                const idle = (rc6 - root.lastRc6) / ((t - root.lastT) * 1000);
                root.gpu = Math.max(0, Math.min(1, 1 - idle));
            }
            root.lastRc6 = rc6;
        } else if (f.amd !== undefined) {
            root.gpu = Math.max(0, Math.min(1, parseFloat(f.amd) / 100));
        } else if (f.nv !== undefined) {
            const n = f.nv.split(",").map(Number);
            if (n[0] >= 0)
                root.gpu = Math.min(1, n[0] / 100);
            if (n[1] > 0)
                root.gpuTemp = n[1];
            if (n[3] > 0) {
                root.gpuMemUsed = n[2] * 1048576;
                root.gpuMemTotal = n[3] * 1048576;
            }
        }
        root.lastT = t;

        if (f.ctemp > 0)
            root.cpuTemp = Math.round(f.ctemp / 1000);
        if (f.gtemp > 0)
            root.gpuTemp = Math.round(f.gtemp / 1000);
        if (f.vendor)
            root.gpuVendor = ({ "0x8086": "Intel", "0x1002": "AMD", "0x10de": "NVIDIA" })[f.vendor] ?? "";

        const h = root.history.slice(-59);
        h.push({ cpu: root.cpu, gpu: Math.max(0, root.gpu), mem: root.memory });
        root.history = h;
    }

    function parseDisks(text: string): void {
        const seen = {};
        const out = [];
        for (const line of text.split("\n")) {
            const p = line.trim().split(/\s+/);
            if (p.length < 5 || !p[0].startsWith("/"))
                continue;
            const [source, size, used, avail] = [p[0], Number(p[1]), Number(p[2]), Number(p[3])];
            const target = p.slice(4).join(" ");
            if (!(size > 0) || /^\/(boot|efi|run|snap|var\/lib\/(docker|containers))/.test(target))
                continue;
            if (seen[source] !== undefined) {
                if (target.length < out[seen[source]].target.length)
                    out[seen[source]].target = target;
                continue;
            }
            seen[source] = out.length;
            out.push({ source, size, used, avail, target });
        }
        for (const d of out)
            d.name = d.target === "/" ? "system" : d.target === Config.home ? "home" : d.target.split("/").pop() || d.target;
        out.sort((a, b) => (a.target === "/" ? -1 : b.target === "/" ? 1 : b.size - a.size));
        root.disks = out;
    }

    function parseHogs(text: string): void {
        const map = {};
        for (const line of text.split("\n")) {
            const p = line.trim().split(/\s+/);
            if (p.length < 2)
                continue;
            const rss = Number(p[0]) * 1024;
            const name = p.slice(1).join(" ");
            if (rss > 0 && name)
                map[name] = (map[name] ?? 0) + rss;
        }
        root.hogs = Object.keys(map).map(name => ({ name, rss: map[name] })).sort((a, b) => b.rss - a.rss).slice(0, 5);
    }

    Process {
        id: sampler

        running: root.active
        command: ["sh", "-c", `
rc6=; for f in /sys/class/drm/card*/gt/gt0/rc6_residency_ms /sys/class/drm/card*/device/tile0/gt0/gtidle/idle_residency_ms; do [ -r "$f" ] && { rc6=$f; break; }; done
amd=; for f in /sys/class/drm/card*/device/gpu_busy_percent; do [ -r "$f" ] && { amd=$f; break; }; done
nv=; [ -z "$rc6$amd" ] && command -v nvidia-smi >/dev/null 2>&1 && nv=1
vendor=; for f in /sys/class/drm/card*/device/vendor; do [ -r "$f" ] && { read -r vendor < "$f"; break; }; done
ct=; gt=
for h in /sys/class/hwmon/hwmon*; do
  read -r n < "$h/name" 2>/dev/null || continue
  case "$n" in
    coretemp|k10temp|zenpower|cpu_thermal) [ -z "$ct" ] && [ -r "$h/temp1_input" ] && ct=$h/temp1_input ;;
    amdgpu|nouveau) [ -z "$gt" ] && [ -r "$h/temp1_input" ] && gt=$h/temp1_input ;;
  esac
done
[ -z "$ct" ] && for z in /sys/class/thermal/thermal_zone*; do [ -r "$z/temp" ] && { ct=$z/temp; break; }; done
while :; do
  read -r up _ < /proc/uptime
  read -r _ u n s i w q sq st _ < /proc/stat
  mt=0; ma=0; stt=0; sf=0
  while read -r k v _; do
    case "$k" in MemTotal:) mt=$v ;; MemAvailable:) ma=$v ;; SwapTotal:) stt=$v ;; SwapFree:) sf=$v ;; esac
  done < /proc/meminfo
  line="t=$up cpu=$u,$n,$s,$i,$w,$q,$sq,$st mem=$mt,$ma,$stt,$sf vendor=$vendor"
  [ -n "$rc6" ] && { read -r r < "$rc6"; line="$line rc6=$r"; }
  [ -n "$amd" ] && { read -r a < "$amd"; line="$line amd=$a"; }
  [ -n "$nv" ] && line="$line nv=$(nvidia-smi --query-gpu=utilization.gpu,temperature.gpu,memory.used,memory.total --format=csv,noheader,nounits 2>/dev/null | head -n1 | tr -d ' ')"
  [ -n "$ct" ] && { read -r c < "$ct"; line="$line ctemp=$c"; }
  [ -n "$gt" ] && { read -r g < "$gt"; line="$line gtemp=$g"; }
  echo "$line"
  sleep 2
done`]
        stdout: SplitParser {
            onRead: line => root.parse(line)
        }
        onRunningChanged: {
            if (!running) {
                root.lastCpu = null;
                root.lastRc6 = -1;
            }
        }
    }

    Process {
        id: df

        command: ["df", "-B1", "-x", "tmpfs", "-x", "devtmpfs", "-x", "efivarfs", "-x", "overlay", "-x", "squashfs", "-x", "fuse.portal", "--output=source,size,used,avail,target"]
        stdout: StdioCollector {
            onStreamFinished: root.parseDisks(text)
        }
    }

    Process {
        id: ps

        command: ["ps", "-eo", "rss=,comm="]
        stdout: StdioCollector {
            onStreamFinished: root.parseHogs(text)
        }
    }

    Timer {
        running: root.active
        interval: root.detailed ? 3000 : 30000
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            df.running = true;
            if (root.detailed)
                ps.running = true;
        }
    }

    FileView {
        path: Config.demo ? "" : "/proc/cpuinfo"
        blockLoading: false
        onLoaded: {
            const m = text().match(/model name\s*:\s*(.+)/);
            if (m)
                root.cpuName = m[1].replace(/\(R\)|\(TM\)|CPU|@.*$|\d+(th|rd|nd|st) Gen/g, "").replace(/\s+/g, " ").trim();
        }
    }
}
