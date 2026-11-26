pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs.config

Singleton {
    id: root

    readonly property bool demo: Config.demo
    property list<Entry> list: []
    readonly property list<Entry> popups: list.filter(e => e.popup)
    readonly property int count: list.length
    property bool dnd: Config.notifications.dnd
    property bool centreOpen: false

    onDndChanged: {
        if (Config.notifications.dnd !== dnd)
            Config.notifications.dnd = dnd;
    }

    function add(e: Entry): void {
        e.popup = !dnd && !centreOpen;
        list = [e, ...list];
    }

    function remove(e: Entry): void {
        list = list.filter(x => x !== e);
        e.destroy();
    }

    function hidePopup(e: Entry): void {
        e.popup = false;
        list = list.slice();
    }

    function clear(): void {
        for (const e of list.slice())
            e.dismiss();
    }

    function hideAllPopups(): void {
        for (const e of list)
            e.popup = false;
        list = list.slice();
    }

    component Entry: QtObject {
        id: entry

        property Notification notif
        property string appName: notif?.appName ?? ""
        property string appIcon: notif?.appIcon ?? ""
        property string summary: notif?.summary ?? ""
        property string body: notif?.body ?? ""
        property string image: notif?.image ?? ""
        property int urgency: notif?.urgency ?? NotificationUrgency.Normal
        property var actions: (notif?.actions ?? []).filter(a => a.identifier !== "default" && (a.text ?? "").trim() !== "")
        readonly property var defaultAction: (notif?.actions ?? []).find(a => a.identifier === "default") ?? null
        property int timeout: (notif?.expireTimeout ?? -1) > 0 ? notif.expireTimeout : Config.notifications.timeout
        property date time: new Date()
        property bool popup: false

        property Connections conn: Connections {
            target: entry.notif

            function onClosed(): void {
                root.remove(entry);
            }
        }

        function dismiss(): void {
            if (notif)
                notif.dismiss();
            else
                root.remove(entry);
        }

        function activate(): void {
            if (defaultAction)
                invoke(defaultAction);
        }

        function invoke(action: var): void {
            action.invoke();
            if (notif && !notif.resident)
                notif.dismiss();
        }
    }

    Component {
        id: entryComp

        Entry {}
    }

    LazyLoader {
        active: !root.demo

        NotificationServer {
            id: server

            keepOnReload: false
            actionsSupported: true
            bodySupported: true
            bodyMarkupSupported: false
            imageSupported: true
            persistenceSupported: true

            onNotification: n => {
                n.tracked = true;
                root.add(entryComp.createObject(root, { notif: n }));
            }
        }
    }

    Component.onCompleted: {
        if (!demo)
            return;
        const now = Date.now();
        const samples = [
            { appName: "Firefox", appIcon: "firefox", summary: "Download complete", body: "fiordland-1.0-x86_64.iso finished downloading", time: new Date(now - 60000) },
            { appName: "Discord", appIcon: "discord", summary: "Aroha", body: "are we still on for the hike up to the lake tomorrow?", time: new Date(now - 420000) },
            { appName: "kuaka", appIcon: "system-software-update", summary: "Updates ready", body: "14 packages can be updated", time: new Date(now - 3600000) }
        ];
        const made = [];
        for (const s of samples) {
            const e = entryComp.createObject(root, s) as Entry;
            e.popup = made.length === 0;
            made.push(e);
        }
        list = made;
    }
}
