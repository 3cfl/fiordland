pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import qs.config

Scope {
    id: root

    property bool active: false
    property string state: ""
    property string message: ""
    property bool fprintReady: false
    property int fprintTries: 0
    property string pending: ""
    readonly property bool busy: passwd.active
    readonly property string user: Quickshell.env("USER") ?? ""

    signal failed
    signal succeeded

    function submit(password: string): void {
        if (passwd.active || state === "maxtries" || password.length === 0)
            return;
        pending = password;
        state = "busy";
        message = "";
        passwd.start();
    }

    function reset(): void {
        pending = "";
        state = "";
        message = "";
        fprintTries = 0;
        if (passwd.active)
            passwd.abort();
        if (fprint.active)
            fprint.abort();
    }

    function startFprint(): void {
        if (active && fprintReady && Config.lock.fingerprint && !fprint.active && fprintTries < 3)
            fprint.start();
    }

    onActiveChanged: {
        reset();
        if (active && Config.lock.fingerprint)
            probe.running = true;
    }

    onFprintReadyChanged: startFprint()

    PamContext {
        id: passwd

        config: "passwd"
        configDirectory: Quickshell.shellPath("assets/pam.d")

        onResponseRequiredChanged: {
            if (!responseRequired)
                return;
            respond(root.pending);
            root.pending = "";
        }

        onCompleted: result => {
            root.pending = "";
            if (result === PamResult.Success) {
                root.state = "ok";
                if (fprint.active)
                    fprint.abort();
                root.succeeded();
                return;
            }
            if (result === PamResult.MaxTries) {
                root.state = "maxtries";
                root.message = "too many tries, wait a moment";
                lockout.restart();
            } else if (result === PamResult.Error) {
                root.state = "error";
                root.message = "something went wrong, try again";
            } else {
                root.state = "failed";
                root.message = passwd.messageIsError && passwd.message ? passwd.message.toLowerCase() : "that's not it, try again";
            }
            root.failed();
        }

        onError: {
            root.pending = "";
            root.state = "error";
            root.message = "couldn't start authentication";
            root.failed();
        }
    }

    PamContext {
        id: fprint

        config: "fprint"
        configDirectory: Quickshell.shellPath("assets/pam.d")

        onCompleted: result => {
            if (result === PamResult.Success) {
                root.state = "ok";
                if (passwd.active)
                    passwd.abort();
                root.succeeded();
                return;
            }
            root.fprintTries++;
            if (root.fprintTries < 3)
                retry.restart();
        }
    }

    Timer {
        id: retry

        interval: 800
        onTriggered: root.startFprint()
    }

    Timer {
        id: lockout

        interval: 30000
        onTriggered: {
            if (root.state === "maxtries") {
                root.state = "";
                root.message = "";
            }
        }
    }

    Process {
        id: probe

        command: ["fprintd-list", root.user]
        stdout: StdioCollector {
            onStreamFinished: root.fprintReady = /finger/i.test(text) && !/no fingers/i.test(text)
        }
    }
}
