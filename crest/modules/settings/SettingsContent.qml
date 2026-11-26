pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Dialogs
import QtQuick.Layouts
import Quickshell
import qs.components
import qs.config
import qs.services
import qs.theme

Rectangle {
    id: root

    property string page: Panels.settingsPage
    property string editing: ""
    property string bindQuery: ""
    readonly property var pages: [
        { id: "account", icon: "account_circle", label: "account" },
        { id: "appearance", icon: "palette", label: "look" },
        { id: "bar", icon: "toolbar", label: "shell" },
        { id: "apps", icon: "apps", label: "apps" },
        { id: "keybinds", icon: "keyboard", label: "keys" },
        { id: "performance", icon: "speed", label: "speed" },
        { id: "wallpaper", icon: "wallpaper", label: "wallpaper" },
        { id: "about", icon: "info", label: "about" }
    ]
    readonly property var titles: ({
            account: ["your account", "how you show up on this computer"],
            appearance: ["look and feel", "colours, theme and effects"],
            bar: ["the shell", "what the bar and dashboard show"],
            apps: ["default apps", "what opens your links and files"],
            keybinds: ["keyboard shortcuts", "click a shortcut to change it"],
            performance: ["speed", "trade effects for responsiveness"],
            wallpaper: ["wallpaper", "the picture behind everything"],
            about: ["about crest", ""]
        })

    signal closeRequested

    color: Colours.surface
    focus: true
    Keys.onEscapePressed: root.editing !== "" ? root.editing = "" : closeRequested()

    onPageChanged: {
        editing = "";
        flick.contentY = 0;
    }

    Component.onCompleted: {
        Account.refresh();
        Defaults.refresh();
        Binds.refresh();
    }

    FileDialog {
        id: facePicker

        title: "choose a profile picture"
        nameFilters: ["images (*.png *.jpg *.jpeg *.webp)"]
        onAccepted: Account.setFace(decodeURIComponent(selectedFile.toString().replace(/^file:\/\//, "")))
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        ColumnLayout {
            Layout.preferredWidth: 96
            Layout.fillHeight: true
            Layout.topMargin: 24
            spacing: 4

            Item {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 44
                Layout.preferredHeight: 44
                Layout.bottomMargin: 16

                ExprShape {
                    anchors.fill: parent
                    shape: "sunny"
                    color: Colours.primaryContainer
                }

                Icon {
                    anchors.centerIn: parent
                    name: "landscape"
                    fill: 1
                    size: 22
                    color: Colours.fgPrimaryContainer
                }
            }

            Repeater {
                model: root.pages

                Item {
                    id: nav

                    required property var modelData
                    readonly property bool selected: root.page === modelData.id

                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 80
                    Layout.preferredHeight: 58

                    Rectangle {
                        id: navPill

                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 2
                        width: nav.selected ? 56 : 32
                        height: 32
                        radius: 16
                        color: nav.selected ? Colours.secondaryContainer : "transparent"

                        Behavior on width {
                            SpringFast {}
                        }

                        Behavior on color {
                            ColorEase {}
                        }
                    }

                    Icon {
                        anchors.centerIn: navPill
                        name: nav.modelData.icon
                        size: 22
                        fill: nav.selected ? 1 : 0
                        color: nav.selected ? Colours.fgSecondaryContainer : Colours.fgSurfaceVariant
                    }

                    Txt {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 38
                        text: nav.modelData.label
                        role: "labelM"
                        color: nav.selected ? Colours.fgSurface : Colours.fgSurfaceVariant
                        elide: Text.ElideNone
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.page = nav.modelData.id
                    }
                }
            }

            Item {
                Layout.fillHeight: true
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: 12
            Layout.bottomMargin: 12
            Layout.rightMargin: 12
            radius: Style.rXl
            color: Colours.surfaceContainerLow

            Flickable {
                id: flick

                anchors.fill: parent
                anchors.leftMargin: 32
                anchors.rightMargin: 32
                contentHeight: pageCol.implicitHeight + 64
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: pageCol

                    y: 32
                    width: flick.width
                    spacing: 24

                    ColumnLayout {
                        spacing: 4

                        Txt {
                            text: (root.titles[root.page] ?? [""])[0]
                            role: "headlineM"
                        }

                        Txt {
                            visible: text !== ""
                            text: (root.titles[root.page] ?? ["", ""])[1]
                            role: "bodyL"
                            color: Colours.fgSurfaceVariant
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: root.page === "account"
                        spacing: 24

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 136
                            radius: Style.rXl
                            color: Colours.surfaceContainerHigh

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 24
                                anchors.rightMargin: 24
                                spacing: 20

                                Item {
                                    Layout.preferredWidth: 88
                                    Layout.preferredHeight: 88

                                    Avatar {
                                        anchors.fill: parent
                                        source: Account.face
                                        initial: Account.displayName
                                        shape: "cookie9"
                                    }

                                    Rectangle {
                                        anchors.right: parent.right
                                        anchors.bottom: parent.bottom
                                        width: 32
                                        height: 32
                                        radius: 16
                                        color: Colours.primary
                                        border.width: 3
                                        border.color: Colours.surfaceContainerHigh

                                        Icon {
                                            anchors.centerIn: parent
                                            name: "edit"
                                            size: 16
                                            fill: 1
                                            color: Colours.fgPrimary
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: facePicker.open()
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    TextInput {
                                        id: nameInput

                                        Layout.fillWidth: true
                                        text: Account.displayName
                                        color: Colours.fgSurface
                                        selectionColor: Colours.primary
                                        selectedTextColor: Colours.fgPrimary
                                        font.family: Style.display
                                        font.pixelSize: 26
                                        font.weight: 500
                                        clip: true
                                        selectByMouse: true
                                        onEditingFinished: if (text.trim() !== "" && text.trim() !== Account.displayName)
                                            Account.setRealName(text.trim())

                                        Rectangle {
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.top: parent.bottom
                                            height: 2
                                            radius: 1
                                            color: nameInput.activeFocus ? Colours.primary : "transparent"
                                        }
                                    }

                                    Txt {
                                        text: `${Account.user} · ${Account.shell.split("/").pop() || "shell"}`
                                        role: "bodyM"
                                        color: Colours.fgSurfaceVariant
                                    }
                                }
                            }
                        }

                        Section {
                            title: "sign in"

                            SettingRow {
                                icon: "password"
                                title: "password"
                                subtitle: "change the password you sign in and unlock with"

                                PillButton {
                                    size: 36
                                    variant: "tonal"
                                    text: "change"
                                    onClicked: Account.changePassword()
                                }
                            }

                            SettingRow {
                                icon: "fingerprint"
                                title: "fingerprint unlock"
                                subtitle: "use a fingerprint reader on the lock screen"

                                Switch {
                                    checked: Config.lock.fingerprint
                                    onToggled: on => Config.lock.fingerprint = on
                                }
                            }

                            SettingRow {
                                icon: "lock_clock"
                                title: "lock before sleep"

                                Switch {
                                    checked: Config.lock.lockBeforeSleep
                                    onToggled: on => Config.lock.lockBeforeSleep = on
                                }
                            }
                        }

                        Section {
                            title: "passwords and keys"

                            SettingRow {
                                icon: "key"
                                title: "keyring"
                                subtitle: ({ off: "not running, apps can't save passwords", empty: "ready, created the first time an app saves a password", locked: "locked, unlocks when you sign in", unlocked: "unlocked, apps can save passwords" })[Account.keyringState]

                                Rectangle {
                                    implicitWidth: krRow.implicitWidth + 20
                                    implicitHeight: 30
                                    radius: 15
                                    color: Account.keyring ? Colours.primaryContainer : Colours.errorContainer

                                    Row {
                                        id: krRow

                                        anchors.centerIn: parent
                                        spacing: 6

                                        Icon {
                                            name: Account.keyring ? "check_circle" : "error"
                                            size: 16
                                            fill: 1
                                            color: Account.keyring ? Colours.fgPrimaryContainer : Colours.fgErrorContainer
                                        }

                                        Txt {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: Account.keyring ? (Account.keyringState === "locked" ? "locked" : "active") : "off"
                                            role: "labelM"
                                            color: Account.keyring ? Colours.fgPrimaryContainer : Colours.fgErrorContainer
                                            elide: Text.ElideNone
                                        }
                                    }
                                }
                            }

                            SettingRow {
                                id: seahorseRow

                                readonly property var app: Apps.entries.find(e => e.id.toLowerCase().includes("seahorse")) ?? null

                                icon: "manage_accounts"
                                title: "manage saved passwords"
                                subtitle: app ? "open passwords and keys" : "install seahorse to browse the keyring"
                                enabled: app !== null

                                IconButton {
                                    size: 36
                                    icon: "open_in_new"
                                    iconSize: 18
                                    onClicked: Apps.launch(seahorseRow.app)
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: root.page === "appearance"
                        spacing: 24

                        Section {
                            title: "colours"

                            SettingRow {
                                icon: "contrast"
                                title: "theme"

                                Segmented {
                                    size: 36
                                    options: [{ id: "dark", icon: "dark_mode", label: "dark" }, { id: "light", icon: "light_mode", label: "light" }]
                                    current: Config.appearance.mode === "light" ? "light" : "dark"
                                    onPicked: id => Config.appearance.mode = id
                                }
                            }

                            SettingRow {
                                icon: "colorize"
                                title: "colours from wallpaper"
                                subtitle: "off uses the fiordland blues"

                                Switch {
                                    checked: Config.appearance.scheme === "wallpaper"
                                    onToggled: on => Config.appearance.scheme = on ? "wallpaper" : "fiordland"
                                }
                            }

                            SettingRow {
                                icon: "format_paint"
                                title: "colour style"
                                subtitle: "how strongly the wallpaper tints the shell"
                                enabled: Config.appearance.scheme === "wallpaper"

                                Segmented {
                                    size: 36
                                    options: [{ id: "scheme-tonal-spot", label: "calm" }, { id: "scheme-content", label: "faithful" }, { id: "scheme-expressive", label: "expressive" }, { id: "scheme-vibrant", label: "vibrant" }]
                                    current: Config.appearance.variant
                                    onPicked: id => Config.appearance.variant = id
                                }
                            }

                            SettingRow {
                                icon: "web_asset"
                                title: "app colours"
                                subtitle: "match file pickers, thunar and other gtk apps to the shell"

                                Switch {
                                    checked: Config.appearance.apps
                                    onToggled: on => Config.appearance.apps = on
                                }
                            }

                            SettingRow {
                                icon: "terminal"
                                title: "terminal colours"
                                subtitle: "match kitty to the shell colours"

                                Switch {
                                    checked: Config.appearance.terminal
                                    onToggled: on => Config.appearance.terminal = on
                                }
                            }
                        }

                        Section {
                            title: "effects"

                            SettingRow {
                                icon: "blur_on"
                                title: "transparency"
                                subtitle: "glass panels with blur behind them"

                                Switch {
                                    checked: Config.appearance.transparency
                                    onToggled: on => Config.appearance.transparency = on
                                }
                            }

                            SettingRow {
                                icon: "nightlight"
                                title: "night light"
                                subtitle: NightLight.enabled ? `${NightLight.temperature} K` : "warmer colours in the evening"

                                Switch {
                                    checked: NightLight.enabled
                                    onToggled: NightLight.toggle()
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: root.page === "bar"
                        spacing: 24

                        Section {
                            title: "bar"

                            SettingRow {
                                icon: "grid_view"
                                title: "workspaces shown"

                                Segmented {
                                    size: 36
                                    options: [{ id: "4", label: "4" }, { id: "5", label: "5" }, { id: "7", label: "7" }, { id: "10", label: "10" }]
                                    current: String(Config.bar.workspaces)
                                    onPicked: id => Config.bar.workspaces = parseInt(id)
                                }
                            }

                            SettingRow {
                                icon: "schedule"
                                title: "24 hour clock"

                                Switch {
                                    checked: Config.bar.use24h
                                    onToggled: on => Config.bar.use24h = on
                                }
                            }

                            SettingRow {
                                icon: "timer"
                                title: "show seconds"

                                Switch {
                                    checked: Config.bar.showSeconds
                                    onToggled: on => Config.bar.showSeconds = on
                                }
                            }

                            SettingRow {
                                icon: "battery_android_full"
                                title: "battery percentage"

                                Switch {
                                    checked: Config.bar.batteryPercent
                                    onToggled: on => Config.bar.batteryPercent = on
                                }
                            }

                            SettingRow {
                                icon: "music_note"
                                title: "now playing"
                                subtitle: "song title next to the clock"

                                Switch {
                                    checked: Config.bar.showMedia
                                    onToggled: on => Config.bar.showMedia = on
                                }
                            }

                            SettingRow {
                                icon: "monitoring"
                                title: "system stats"
                                subtitle: "cpu and memory rings next to the clock"

                                Switch {
                                    checked: Config.bar.showStats
                                    onToggled: on => Config.bar.showStats = on
                                }
                            }

                            SettingRow {
                                icon: "widgets"
                                title: "tray icons"

                                Switch {
                                    checked: Config.bar.showTray
                                    onToggled: on => Config.bar.showTray = on
                                }
                            }
                        }

                        Section {
                            title: "dashboard"

                            SettingRow {
                                icon: "lyrics"
                                title: "lyrics"
                                subtitle: "synced lyrics in the music player, from lrclib.net"

                                Switch {
                                    checked: Config.media.lyrics
                                    onToggled: on => Config.media.lyrics = on
                                }
                            }

                            SettingRow {
                                icon: "content_paste"
                                title: "clipboard history"
                                subtitle: Clip.available || !Clip.probed ? "remember what you copy, super+v" : "needs cliphist installed"

                                Switch {
                                    checked: Config.clipboard.enabled
                                    onToggled: on => Config.clipboard.enabled = on
                                }
                            }

                            SettingRow {
                                icon: "notifications"
                                title: "notification time"
                                subtitle: "how long popups stay on screen"

                                Segmented {
                                    size: 36
                                    options: [{ id: "4000", label: "4s" }, { id: "6000", label: "6s" }, { id: "10000", label: "10s" }]
                                    current: String(Config.notifications.timeout)
                                    onPicked: id => Config.notifications.timeout = parseInt(id)
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: root.page === "apps"
                        spacing: 24

                        Section {
                            title: "web browser"

                            Repeater {
                                model: Defaults.browsers

                                SettingRow {
                                    id: brow

                                    required property var modelData
                                    readonly property bool chosen: Defaults.isBrowser(modelData)

                                    appIcon: Apps.icon(modelData.icon)
                                    title: modelData.name
                                    subtitle: chosen ? "default, opens links and super+b" : (modelData.genericName ?? "")
                                    clickable: !chosen
                                    onClicked: Defaults.setBrowser(modelData.id)

                                    Rectangle {
                                        width: 22
                                        height: 22
                                        radius: 11
                                        color: "transparent"
                                        border.width: 2
                                        border.color: brow.chosen ? Colours.primary : Colours.outline

                                        Rectangle {
                                            anchors.centerIn: parent
                                            width: 10
                                            height: 10
                                            radius: 5
                                            color: Colours.primary
                                            visible: brow.chosen
                                        }
                                    }
                                }
                            }
                        }

                        Txt {
                            Layout.fillWidth: true
                            visible: Defaults.browsers.length === 0
                            text: "no browsers found"
                            role: "bodyL"
                            color: Colours.fgSurfaceVariant
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: root.page === "keybinds"
                        spacing: 24

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 48
                                radius: 24
                                color: Colours.surfaceContainerHigh

                                Icon {
                                    x: 16
                                    anchors.verticalCenter: parent.verticalCenter
                                    name: "search"
                                    size: 20
                                    color: Colours.fgSurfaceVariant
                                }

                                TextInput {
                                    id: bindSearch

                                    x: 48
                                    width: parent.width - 64
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: Colours.fgSurface
                                    font.family: Style.font
                                    font.pixelSize: 15
                                    clip: true
                                    onTextChanged: root.bindQuery = text.toLowerCase()

                                    Txt {
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: bindSearch.text === ""
                                        text: "search shortcuts"
                                        role: "bodyL"
                                        color: Colours.fgSurfaceVariant
                                    }
                                }
                            }

                            PillButton {
                                visible: Object.keys(Binds.overrides).length > 0
                                size: 40
                                variant: "tonal"
                                icon: "restart_alt"
                                text: "reset all"
                                onClicked: Binds.resetAll()
                            }
                        }

                        Repeater {
                            model: ["shell", "apps", "windows", "workspaces", "capture", "media & hardware", "other"]

                            Section {
                                id: group

                                required property string modelData
                                readonly property var items: Binds.list.filter(b => b.group === modelData && (root.bindQuery === "" || b.label.includes(root.bindQuery) || b.current.toLowerCase().includes(root.bindQuery)))

                                title: modelData
                                visible: items.length > 0

                                Repeater {
                                    model: group.items

                                    BindRow {}
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: root.page === "performance"
                        spacing: 16

                        Section {
                            title: "effects"

                            SettingRow {
                                icon: "eco"
                                title: "low-end mode"
                                subtitle: "turns off blur, shadows and most motion"

                                Segmented {
                                    size: 36
                                    options: [{ id: "auto", label: "auto" }, { id: "on", label: "on" }, { id: "off", label: "off" }]
                                    current: Config.performance.lowEnd
                                    onPicked: id => Config.performance.lowEnd = id
                                }
                            }

                            SettingRow {
                                icon: Perf.lowEnd ? "eco" : "bolt"
                                title: Perf.lowEnd ? "low-end mode is on" : "full effects are on"
                                subtitle: Perf.lowEnd && Perf.mode === "auto" ? `because of ${Perf.reason}` : ""
                            }
                        }

                        Section {
                            title: "this computer"

                            SettingRow {
                                icon: "memory"
                                title: "memory"

                                Txt {
                                    text: Perf.memoryMb > 0 ? (Perf.memoryMb / 1024).toFixed(1) + " GB" : "unknown"
                                    role: "bodyL"
                                    color: Colours.fgSurfaceVariant
                                }
                            }

                            SettingRow {
                                icon: "developer_board"
                                title: "graphics"

                                Txt {
                                    text: Perf.softwareGpu ? "software" : "hardware"
                                    role: "bodyL"
                                    color: Colours.fgSurfaceVariant
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: root.page === "wallpaper"
                        spacing: 16

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: width * 9 / 16
                            Layout.maximumHeight: 320
                            radius: Style.rXl
                            color: Colours.surfaceContainerHighest
                            clip: true

                            Image {
                                anchors.fill: parent
                                source: Wallpapers.current
                                sourceSize.width: 720
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                            }
                        }

                        RowLayout {
                            spacing: 8

                            PillButton {
                                icon: "photo_library"
                                text: "pick a wallpaper"
                                onClicked: {
                                    root.closeRequested();
                                    Panels.show("wallpaper");
                                }
                            }

                            PillButton {
                                variant: "tonal"
                                icon: "restart_alt"
                                text: "use the default"
                                onClicked: Wallpapers.set(Wallpapers.fallback)
                            }
                        }

                        Txt {
                            Layout.fillWidth: true
                            wrapMode: Text.Wrap
                            text: "crest looks in ~/Pictures/Wallpapers, ~/Pictures and /usr/share/backgrounds."
                            role: "bodyM"
                            color: Colours.fgSurfaceVariant
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: root.page === "about"
                        spacing: 12

                        RowLayout {
                            spacing: 20

                            Item {
                                Layout.preferredWidth: 88
                                Layout.preferredHeight: 88

                                ExprShape {
                                    anchors.fill: parent
                                    shape: "cookie9"
                                    color: Colours.primary
                                }

                                Icon {
                                    anchors.centerIn: parent
                                    name: "landscape"
                                    size: 44
                                    fill: 1
                                    color: Colours.fgPrimary
                                }
                            }

                            ColumnLayout {
                                spacing: 2

                                Txt {
                                    text: "crest 1"
                                    role: "headlineS"
                                }

                                Txt {
                                    text: "the fiordland desktop shell"
                                    role: "bodyL"
                                    color: Colours.fgSurfaceVariant
                                }
                            }
                        }

                        Section {
                            Layout.topMargin: 12
                            title: "details"

                            SettingRow {
                                icon: "deployed_code"
                                title: "built on"

                                Txt {
                                    text: "quickshell + hyprland"
                                    role: "bodyL"
                                    color: Colours.fgSurfaceVariant
                                }
                            }

                            SettingRow {
                                icon: "favorite"
                                title: "inspired by"

                                Txt {
                                    text: "caelestia, end-4"
                                    role: "bodyL"
                                    color: Colours.fgSurfaceVariant
                                }
                            }

                            SettingRow {
                                icon: "gavel"
                                title: "licence"

                                Txt {
                                    text: "GPL-3.0, free software"
                                    role: "bodyL"
                                    color: Colours.fgSurfaceVariant
                                }
                            }

                            SettingRow {
                                icon: "language"
                                title: "fiordlandlinux.org"
                                clickable: true
                                onClicked: Qt.openUrlExternally("https://fiordlandlinux.org")

                                Icon {
                                    name: "open_in_new"
                                    size: 18
                                    color: Colours.fgSurfaceVariant
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    component Section: ColumnLayout {
        id: sec

        property string title
        default property alias rows: list.data

        Layout.fillWidth: true
        spacing: 8

        Txt {
            Layout.leftMargin: 4
            text: sec.title
            role: "labelL"
            color: Colours.primary
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: list.implicitHeight
            radius: Style.rXl
            color: Colours.surfaceContainerHigh
            clip: true

            ColumnLayout {
                id: list

                width: parent.width
                spacing: 0
            }
        }
    }

    component SettingRow: Item {
        id: row

        property string title
        property string subtitle
        property string icon
        property string appIcon
        property bool clickable: false
        readonly property bool first: {
            const kids = parent ? parent.children : [];
            for (let i = 0; i < kids.length; i++)
                if (kids[i].visible && kids[i] instanceof Item && kids[i].implicitHeight > 0)
                    return kids[i] === row;
            return true;
        }
        property bool divided: !first
        default property alias trailing: slot.data

        signal clicked

        Layout.fillWidth: true
        implicitHeight: Math.max(subtitle !== "" ? 72 : 60, slot.childrenRect.height + 24)
        opacity: enabled ? 1 : 0.45

        Rectangle {
            visible: row.divided
            x: 20
            width: parent.width - 40
            height: 1
            color: Colours.alpha(Colours.outlineVariant, 0.5)
        }

        StateLayer {
            enabled: row.clickable
            visible: row.clickable
            onClicked: row.clicked()
        }

        Icon {
            id: rowIcon

            visible: row.icon !== ""
            x: 20
            anchors.verticalCenter: parent.verticalCenter
            name: row.icon
            size: 22
            color: Colours.fgSurfaceVariant
        }

        Image {
            id: rowApp

            visible: row.appIcon !== ""
            x: 18
            anchors.verticalCenter: parent.verticalCenter
            width: 28
            height: 28
            source: row.appIcon
            sourceSize.width: 56
            sourceSize.height: 56
            asynchronous: true
        }

        ColumnLayout {
            anchors.left: parent.left
            anchors.leftMargin: row.icon !== "" || row.appIcon !== "" ? 60 : 20
            anchors.right: slot.left
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Txt {
                Layout.fillWidth: true
                text: row.title
                role: "bodyL"
                font.weight: 500
            }

            Txt {
                Layout.fillWidth: true
                visible: text !== ""
                text: row.subtitle
                role: "bodyM"
                color: Colours.fgSurfaceVariant
            }
        }

        Item {
            id: slot

            anchors.right: parent.right
            anchors.rightMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            width: childrenRect.width
            height: childrenRect.height
        }
    }

    component KeyCap: Rectangle {
        property string label

        implicitWidth: Math.max(28, capTxt.implicitWidth + 16)
        implicitHeight: 28
        radius: Style.rSm
        color: Colours.surfaceContainerHighest
        border.width: 1
        border.color: Colours.alpha(Colours.outlineVariant, 0.8)

        Txt {
            id: capTxt

            anchors.centerIn: parent
            text: parent.label
            role: "labelM"
            font.family: Style.mono
            elide: Text.ElideNone
        }
    }

    component BindRow: ColumnLayout {
        id: bind

        required property var modelData
        required property int index
        readonly property bool open: root.editing === modelData.keys
        property var mods: []
        property string key: ""
        readonly property string combo: [...mods, key].filter(k => k).join(" + ")
        readonly property var clash: key !== "" ? Binds.conflict(combo, modelData.keys) : null

        function begin(): void {
            const parts = modelData.current.split("+").map(k => k.trim());
            mods = parts.filter(k => ["SUPER", "SHIFT", "CTRL", "ALT"].indexOf(k) >= 0);
            key = "";
            root.editing = modelData.keys;
            capture.forceActiveFocus();
        }

        function qtKey(event: var): string {
            const named = { [Qt.Key_Return]: "RETURN", [Qt.Key_Enter]: "RETURN", [Qt.Key_Escape]: "ESCAPE", [Qt.Key_Space]: "SPACE", [Qt.Key_Tab]: "TAB", [Qt.Key_Backspace]: "BACKSPACE", [Qt.Key_Delete]: "DELETE", [Qt.Key_Left]: "left", [Qt.Key_Right]: "right", [Qt.Key_Up]: "up", [Qt.Key_Down]: "down", [Qt.Key_Period]: "PERIOD", [Qt.Key_Comma]: "COMMA", [Qt.Key_Minus]: "MINUS", [Qt.Key_Equal]: "EQUAL", [Qt.Key_Slash]: "SLASH", [Qt.Key_Semicolon]: "SEMICOLON", [Qt.Key_Print]: "Print", [Qt.Key_Home]: "Home", [Qt.Key_End]: "End", [Qt.Key_PageUp]: "Prior", [Qt.Key_PageDown]: "Next", [Qt.Key_Insert]: "Insert", [Qt.Key_BracketLeft]: "bracketleft", [Qt.Key_BracketRight]: "bracketright", [Qt.Key_Apostrophe]: "apostrophe", [Qt.Key_QuoteLeft]: "grave" };
            if (named[event.key])
                return named[event.key];
            if (event.key >= Qt.Key_F1 && event.key <= Qt.Key_F24)
                return "F" + (event.key - Qt.Key_F1 + 1);
            if ((event.key >= Qt.Key_A && event.key <= Qt.Key_Z) || (event.key >= Qt.Key_0 && event.key <= Qt.Key_9))
                return String.fromCharCode(event.key);
            return "";
        }

        Layout.fillWidth: true
        spacing: 0

        SettingRow {
            divided: bind.index > 0
            title: bind.modelData.label
            subtitle: bind.modelData.disabled ? "turned off" : (bind.modelData.changed ? "changed" : "")
            clickable: !bind.modelData.fixed
            onClicked: bind.open ? root.editing = "" : bind.begin()

            Row {
                spacing: 4

                Repeater {
                    model: bind.modelData.disabled ? [] : Binds.pretty(bind.modelData.current)

                    KeyCap {
                        required property string modelData

                        label: modelData
                    }
                }

                Icon {
                    visible: !bind.modelData.fixed
                    anchors.verticalCenter: parent.verticalCenter
                    leftPadding: 6
                    name: bind.open ? "expand_less" : "edit"
                    size: 18
                    color: Colours.fgSurfaceVariant
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.leftMargin: 12
            Layout.rightMargin: 12
            Layout.bottomMargin: 12
            visible: bind.open
            implicitHeight: editCol.implicitHeight + 32
            radius: Style.rLg
            color: Colours.surfaceContainerHighest

            ColumnLayout {
                id: editCol

                x: 16
                y: 16
                width: parent.width - 32
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Repeater {
                        model: ["SUPER", "SHIFT", "CTRL", "ALT"]

                        PillButton {
                            required property string modelData
                            readonly property bool on: bind.mods.indexOf(modelData) >= 0

                            size: 34
                            variant: on ? "filled" : "outlined"
                            text: modelData.toLowerCase()
                            onClicked: {
                                const m = bind.mods.filter(x => x !== modelData);
                                if (!on)
                                    m.push(modelData);
                                bind.mods = ["SUPER", "SHIFT", "CTRL", "ALT"].filter(x => m.indexOf(x) >= 0);
                                capture.forceActiveFocus();
                            }
                        }
                    }

                    Txt {
                        text: "+"
                        role: "titleM"
                        color: Colours.fgSurfaceVariant
                    }

                    Rectangle {
                        id: capBox

                        Layout.fillWidth: true
                        implicitHeight: 34
                        radius: 17
                        color: Colours.surfaceContainerLow
                        border.width: 2
                        border.color: capture.activeFocus ? Colours.primary : Colours.outlineVariant

                        Txt {
                            anchors.centerIn: parent
                            text: bind.key !== "" ? Binds.pretty(bind.key).join("") : (capture.activeFocus ? "press a key" : "click, then press a key")
                            role: bind.key !== "" ? "labelL" : "bodyM"
                            color: bind.key !== "" ? Colours.fgSurface : Colours.fgSurfaceVariant
                        }

                        Item {
                            id: capture

                            anchors.fill: parent
                            Keys.onPressed: event => {
                                const k = bind.qtKey(event);
                                if (k === "")
                                    return;
                                const m = [];
                                if (event.modifiers & Qt.MetaModifier || bind.mods.indexOf("SUPER") >= 0)
                                    m.push("SUPER");
                                if (event.modifiers & Qt.ShiftModifier || bind.mods.indexOf("SHIFT") >= 0)
                                    m.push("SHIFT");
                                if (event.modifiers & Qt.ControlModifier || bind.mods.indexOf("CTRL") >= 0)
                                    m.push("CTRL");
                                if (event.modifiers & Qt.AltModifier || bind.mods.indexOf("ALT") >= 0)
                                    m.push("ALT");
                                bind.mods = m;
                                bind.key = k;
                                event.accepted = true;
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.IBeamCursor
                                onClicked: capture.forceActiveFocus()
                            }
                        }
                    }
                }

                Txt {
                    Layout.fillWidth: true
                    visible: bind.clash !== null
                    text: bind.clash ? `already used by "${bind.clash.label}", saving will override it` : ""
                    role: "bodyM"
                    color: Colours.error
                    wrapMode: Text.Wrap
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    PillButton {
                        size: 36
                        variant: "text"
                        icon: "block"
                        text: "turn off"
                        visible: !bind.modelData.disabled
                        onClicked: {
                            Binds.setBind(bind.modelData.keys, "");
                            root.editing = "";
                        }
                    }

                    PillButton {
                        size: 36
                        variant: "text"
                        icon: "restart_alt"
                        text: "default"
                        visible: bind.modelData.changed
                        onClicked: {
                            Binds.reset(bind.modelData.keys);
                            root.editing = "";
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    PillButton {
                        size: 36
                        variant: "tonal"
                        text: "cancel"
                        onClicked: root.editing = ""
                    }

                    PillButton {
                        size: 36
                        text: "save"
                        enabled: bind.key !== ""
                        opacity: enabled ? 1 : 0.4
                        onClicked: {
                            if (bind.clash && !bind.clash.fixed)
                                Binds.setBind(bind.clash.keys, "");
                            Binds.setBind(bind.modelData.keys, bind.combo);
                            root.editing = "";
                        }
                    }
                }
            }
        }
    }
}
