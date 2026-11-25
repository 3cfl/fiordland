pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property bool demo: Quickshell.env("CREST_DEMO") === "1"
    readonly property string home: Quickshell.env("HOME") ?? ""
    readonly property string dir: (Quickshell.env("XDG_STATE_HOME") || home + "/.local/state") + "/crest-greeter"
    property bool ready: false
    property alias lastUser: adapter.lastUser
    property alias lastSession: adapter.lastSession

    function remember(user: string, session: string): void {
        if (demo || !ready)
            return;
        root.lastUser = user;
        root.lastSession = session;
        file.writeAdapter();
    }

    Process {
        running: !root.demo && root.home !== ""
        command: ["mkdir", "-p", "-m", "700", root.dir]
        onExited: code => root.ready = code === 0
    }

    FileView {
        id: file

        path: root.ready ? root.dir + "/last.json" : ""
        printErrors: false
        atomicWrites: true

        JsonAdapter {
            id: adapter

            property string lastUser: ""
            property string lastSession: ""
        }
    }
}
