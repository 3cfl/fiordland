pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

Singleton {
    id: root

    property bool available: Config.demo
    property bool probed: Config.demo
    readonly property bool watching: available && Config.clipboard.enabled && !Config.demo
    readonly property int keep: Math.max(10, Math.min(2000, Config.clipboard.keep))
    readonly property string runtimeDir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/crest-clip"
    readonly property string favDir: Config.stateDir + "/clipboard"
    property var entries: Config.demo ? [
        { id: "3", text: "fiordland.org", image: false },
        { id: "2", text: "sudo pacman -Syu", image: false },
        { id: "1", text: "", image: true, meta: "png 1920x1080" }
    ] : []
    property var favourites: []
    property int thumbsVersion: 0
    property bool favLoaded: false

    function isFavourite(text: string): bool {
        return text !== "" && favourites.some(f => f.kind === "text" && f.text === text);
    }

    function thumb(id: string): string {
        return /^\d+$/.test(id) ? `file://${runtimeDir}/${id}?v=${thumbsVersion}` : "";
    }

    function refresh(): void {
        if (!available || Config.demo)
            return;
        lister.running = true;
    }

    function parseList(text: string): void {
        const out = [];
        for (const line of text.split("\n")) {
            const tab = line.indexOf("\t");
            if (tab <= 0)
                continue;
            const id = line.slice(0, tab);
            if (!/^\d+$/.test(id))
                continue;
            const body = line.slice(tab + 1);
            const img = body.match(/^\[\[ binary data (.+?) \]\]$/);
            if (img) {
                const m = img[1].match(/(png|jpeg|jpg|gif|webp|bmp)\s+(\d+x\d+)/i);
                out.push({ id, text: "", image: !!m, meta: m ? `${m[1].toLowerCase()} ${m[2]}` : img[1] });
            } else {
                out.push({ id, text: body, image: false });
            }
        }
        root.entries = out;
        const ids = out.filter(e => e.image).slice(0, 40).map(e => e.id);
        if (ids.length > 0) {
            thumbs.command = ["sh", "-c", 'd=$1; shift; mkdir -p -m 700 "$d" || exit 1; for id; do [ -s "$d/$id" ] || cliphist decode "$id" > "$d/$id" 2>/dev/null; done; for f in "$d"/*; do case " $* " in *" ${f##*/} "*) ;; *) rm -f "$f" ;; esac; done', "sh", root.runtimeDir].concat(ids);
            thumbs.running = true;
        }
    }

    function copy(entry: var): void {
        if (Config.demo || !entry)
            return;
        if (entry.kind === "text")
            Quickshell.execDetached(["wl-copy", "--", entry.text]);
        else if (entry.kind === "image")
            Quickshell.execDetached(["sh", "-c", 'wl-copy < "$1"', "sh", entry.file]);
        else if (/^\d+$/.test(entry.id))
            Quickshell.execDetached(["sh", "-c", 'cliphist decode "$1" | wl-copy', "sh", entry.id]);
    }

    function remove(entry: var): void {
        if (Config.demo || !entry || !/^\d+$/.test(entry.id))
            return;
        root.entries = root.entries.filter(e => e.id !== entry.id);
        runner.exec(["sh", "-c", 'printf "%s\\t\\n" "$1" | cliphist delete', "sh", entry.id]);
    }

    function wipe(): void {
        if (Config.demo)
            return;
        root.entries = [];
        runner.exec(["cliphist", "wipe"]);
    }

    function toggleFavourite(entry: var): void {
        if (!entry)
            return;
        if (entry.kind) {
            root.favourites = root.favourites.filter(f => f !== entry);
            if (entry.kind === "image")
                Quickshell.execDetached(["rm", "-f", "--", entry.file]);
            saveFavourites();
            return;
        }
        if (!entry.image) {
            if (isFavourite(entry.text)) {
                root.favourites = root.favourites.filter(f => !(f.kind === "text" && f.text === entry.text));
            } else {
                root.favourites = [{ kind: "text", text: entry.text, added: Date.now() }].concat(root.favourites);
            }
            saveFavourites();
            return;
        }
        if (Config.demo || !/^\d+$/.test(entry.id))
            return;
        const file = `${root.favDir}/${Date.now()}-${entry.id}`;
        root.favourites = [{ kind: "image", file, meta: entry.meta, added: Date.now() }].concat(root.favourites);
        saveFavourites();
        Quickshell.execDetached(["sh", "-c", 'mkdir -p -m 700 "$(dirname "$2")" && cliphist decode "$1" > "$2"', "sh", entry.id, file]);
    }

    function saveFavourites(): void {
        if (Config.demo || !Config.dirsReady)
            return;
        favFile.setText(JSON.stringify(root.favourites.slice(0, 500)));
    }

    Process {
        running: !Config.demo
        command: ["sh", "-c", "command -v cliphist >/dev/null && command -v wl-paste >/dev/null"]
        onExited: code => {
            root.available = code === 0;
            root.probed = true;
        }
    }

    Process {
        id: textWatch

        running: root.watching
        command: ["wl-paste", "--type", "text", "--watch", "cliphist", "-max-items", String(root.keep), "store"]
        onRunningChanged: if (!running && root.watching)
            restart.restart()
    }

    Process {
        id: imageWatch

        running: root.watching
        command: ["wl-paste", "--type", "image", "--watch", "cliphist", "-max-items", String(root.keep), "store"]
        onRunningChanged: if (!running && root.watching)
            restart.restart()
    }

    Timer {
        id: restart

        interval: 5000
        onTriggered: {
            if (!root.watching)
                return;
            textWatch.running = true;
            imageWatch.running = true;
        }
    }

    Process {
        id: lister

        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: root.parseList(text)
        }
    }

    Process {
        id: thumbs

        onExited: root.thumbsVersion++
    }

    Process {
        id: runner

        property var queue: []

        function exec(cmd: var): void {
            if (running) {
                queue = queue.concat([cmd]);
                return;
            }
            command = cmd;
            running = true;
        }

        onExited: {
            if (queue.length > 0) {
                const next = queue[0];
                queue = queue.slice(1);
                command = next;
                running = true;
            } else {
                root.refresh();
            }
        }
    }

    FileView {
        id: favFile

        path: Config.demo || !Config.dirsReady ? "" : Config.stateDir + "/clipboard.json"
        printErrors: false
        onLoaded: {
            try {
                const list = JSON.parse(text());
                if (Array.isArray(list))
                    root.favourites = list.filter(f => f && ((f.kind === "text" && typeof f.text === "string") || (f.kind === "image" && typeof f.file === "string" && f.file.startsWith(root.favDir + "/"))));
            } catch (e) {
                console.warn("crest: ignoring unreadable clipboard favourites");
            }
            root.favLoaded = true;
        }
        onLoadFailed: root.favLoaded = true
    }
}
