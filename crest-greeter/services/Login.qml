pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Greetd

Singleton {
    id: root

    readonly property bool demo: !Greetd.available && Quickshell.env("CREST_DEMO") === "1"
    readonly property bool available: Greetd.available || demo
    property string state: ""
    property string message: ""
    property string prompt: ""
    property bool promptEcho: false
    property string pending: ""
    property bool pamSpoke: false
    property var session: null

    signal failed
    signal launching

    function submit(user: string, session: var, text: string): void {
        if (state === "busy" || state === "launching")
            return;
        if (state === "prompt") {
            state = "busy";
            if (demo)
                demoTimer.restart();
            else
                Greetd.respond(text);
            return;
        }
        if (!session) {
            state = "error";
            message = "no desktop sessions are installed";
            return;
        }
        root.session = session;
        pending = text;
        pamSpoke = false;
        message = "";
        state = "busy";
        if (demo) {
            demoTimer.restart();
            return;
        }
        if (Greetd.state !== GreetdState.Inactive) {
            Greetd.cancelSession();
            pending = "";
            state = "error";
            message = "please try again";
            return;
        }
        Greetd.createSession(user);
    }

    function cancel(): void {
        pending = "";
        prompt = "";
        if (state === "launching")
            return;
        state = "";
        message = "";
        if (!demo && Greetd.state === GreetdState.Authenticating)
            Greetd.cancelSession();
    }

    function quote(word: string): string {
        if (/^[A-Za-z0-9_@%+:,.\/-]+$/.test(word))
            return word;
        return "'" + word.replace(/'/g, "'\\''") + "'";
    }

    function command(s: var): var {
        const argv = s.type === "x11" ? ["startx", "/usr/bin/env"].concat(s.exec, ["--"]) : s.exec;
        return argv.map(quote);
    }

    function environment(s: var): var {
        return [`XDG_SESSION_TYPE=${s.type}`, `XDG_SESSION_DESKTOP=${s.id.replace(/^x11-/, "")}`, `XDG_CURRENT_DESKTOP=${s.desktop}`];
    }

    function fail(text: string): void {
        pending = "";
        prompt = "";
        state = "failed";
        message = text;
        failed();
    }

    Timer {
        id: demoTimer

        interval: 700
        onTriggered: {
            if (root.pending === "fiordland") {
                root.pending = "";
                root.state = "launching";
                root.launching();
                launchTimer.restart();
            } else {
                root.fail("that's not it, try again");
            }
        }
    }

    Timer {
        id: launchTimer

        interval: 650
        onTriggered: {
            if (root.demo) {
                Qt.quit();
                return;
            }
            Greetd.launch(root.command(root.session), root.environment(root.session), true);
        }
    }

    Connections {
        target: Greetd

        function onAuthMessage(message: string, error: bool, responseRequired: bool, echoResponse: bool): void {
            if (responseRequired) {
                if (root.pending !== "" && !echoResponse) {
                    Greetd.respond(root.pending);
                    root.pending = "";
                    return;
                }
                root.pending = "";
                root.prompt = message;
                root.promptEcho = echoResponse;
                root.state = "prompt";
                return;
            }
            if (message !== "") {
                root.message = message;
                root.pamSpoke = error;
            }
        }

        function onAuthFailure(message: string): void {
            root.fail(root.pamSpoke && root.message !== "" ? root.message : "that's not it, try again");
        }

        function onReadyToLaunch(): void {
            root.pending = "";
            root.state = "launching";
            root.launching();
            launchTimer.restart();
        }

        function onError(error: string): void {
            root.pending = "";
            root.prompt = "";
            root.state = "error";
            root.message = "the login service had a problem, please try again";
            if (Greetd.state !== GreetdState.Inactive)
                Greetd.cancelSession();
        }
    }
}
