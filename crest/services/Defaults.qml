pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

Singleton {
    id: root

    property string browser: ""
    readonly property var browsers: Apps.entries.filter(e => (e.categories ?? []).indexOf("WebBrowser") >= 0)

    function refresh(): void {
        getter.running = true;
    }

    function setBrowser(id: string): void {
        const desktop = id.endsWith(".desktop") ? id : id + ".desktop";
        browser = desktop;
        setter.command = ["sh", "-c", 'xdg-settings set default-web-browser "$1"; for m in x-scheme-handler/http x-scheme-handler/https text/html application/xhtml+xml; do xdg-mime default "$1" "$m"; done', "sh", desktop];
        setter.running = true;
    }

    function isBrowser(entry: var): bool {
        return (entry.id.endsWith(".desktop") ? entry.id : entry.id + ".desktop") === browser;
    }

    Process {
        id: getter

        running: !Config.demo
        command: ["xdg-settings", "get", "default-web-browser"]
        stdout: StdioCollector {
            onStreamFinished: root.browser = text.trim()
        }
    }

    Process {
        id: setter

        onExited: getter.running = true
    }
}
