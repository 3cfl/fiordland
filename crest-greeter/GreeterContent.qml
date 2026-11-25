pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.components
import qs.services
import qs.theme

Item {
    id: root

    property string chosenUser: ""
    property string chosenSession: ""
    property bool sessionsOpen: false
    property real enter: 0
    property real leave: 0
    property string wallpaper: "file:///etc/crest-greeter/wallpaper"
    property string hostname: Login.demo ? "fiordland" : ""
    readonly property bool wide: width >= 1000
    readonly property var user: Users.find(chosenUser) ?? Users.find(Prefs.lastUser) ?? Users.list[0] ?? null
    readonly property string userName: user ? user.name : manualUser.text.trim()
    readonly property var session: Sessions.find(chosenSession) ?? Sessions.find(Prefs.lastSession) ?? Sessions.list[0] ?? null
    readonly property string mood: Login.state === "launching" ? "launching" : Login.state === "busy" ? "busy" : (Login.state === "failed" || Login.state === "error") ? "failed" : ""

    Component.onCompleted: enter = 1

    Behavior on enter {
        SpringSlow {}
    }

    function pickUser(name: string): void {
        if (Login.state === "busy" || Login.state === "launching")
            return;
        Login.cancel();
        chosenUser = name;
        field.text = "";
        field.forceActiveFocus();
    }

    function cycleUser(step: int): void {
        const list = Users.list;
        if (list.length < 2 || !user)
            return;
        let i = list.findIndex(u => u.name === user.name);
        i = (i + step + list.length) % list.length;
        pickUser(list[i].name);
    }

    function submit(): void {
        if (Login.state !== "prompt" && (field.text.length === 0 || userName === ""))
            return;
        sessionsOpen = false;
        const text = field.text;
        field.text = "";
        Login.submit(userName, session, text);
    }

    function power(action: string): void {
        if (Login.demo || Login.state === "launching")
            return;
        if (["suspend", "reboot", "poweroff"].indexOf(action) < 0)
            return;
        Quickshell.execDetached(["systemctl", action]);
    }

    Connections {
        target: Login

        function onFailed(): void {
            shakeAnim.restart();
            field.text = "";
            field.forceActiveFocus();
        }

        function onLaunching(): void {
            if (root.session)
                Prefs.remember(root.userName, root.session.id);
            leaveAnim.restart();
        }
    }

    NumberAnimation {
        id: leaveAnim

        target: root
        property: "leave"
        to: 1
        duration: 600
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Motion.emphasizedAccel
    }

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    FileView {
        path: Login.demo ? "" : "/etc/hostname"
        printErrors: false
        onLoaded: root.hostname = text().trim()
    }

    Rectangle {
        anchors.fill: parent
        color: "black"
    }

    Item {
        id: backdrop

        anchors.fill: parent
        opacity: Math.min(1, root.enter * 1.4) * (1 - root.leave)
        scale: 1.04 - 0.04 * root.enter + 0.08 * root.leave

        Image {
            id: wall

            anchors.fill: parent
            source: root.wallpaper
            sourceSize.width: Style.effects ? 1280 : 160
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: !Style.effects
            smooth: true
            onStatusChanged: {
                if (status === Image.Error && root.wallpaper !== Quickshell.shellPath("assets/wallpaper.webp"))
                    root.wallpaper = Quickshell.shellPath("assets/wallpaper.webp");
            }
        }

        MultiEffect {
            anchors.fill: parent
            visible: Style.effects
            source: wall
            blurEnabled: true
            blur: 1
            blurMax: 64
            saturation: 0.2
            brightness: -0.08
        }

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                orientation: root.wide ? Gradient.Horizontal : Gradient.Vertical

                GradientStop {
                    position: 0
                    color: Colours.alpha(Colours.scrim, 0.55)
                }

                GradientStop {
                    position: 0.6
                    color: Colours.alpha(Colours.scrim, 0.2)
                }

                GradientStop {
                    position: 1
                    color: Colours.alpha(Colours.scrim, 0.35)
                }
            }
        }
    }

    Item {
        id: stage

        anchors.fill: parent
        opacity: Math.min(1, root.enter) * (1 - root.leave)

        Column {
            id: clockCol

            x: root.wide ? Math.round(parent.width * 0.09) : Math.round((parent.width - width) / 2)
            y: root.wide ? Math.round((parent.height - height) / 2) - 20 : Math.round(parent.height * 0.07)
            spacing: 0

            transform: Translate {
                x: root.wide ? -(1 - root.enter) * 60 - root.leave * 40 : 0
                y: root.wide ? 0 : -(1 - root.enter) * 40
            }

            Txt {
                height: implicitHeight - (root.wide ? 36 : 24)
                text: Qt.formatDateTime(clock.date, "HH")
                role: "displayL"
                font.pixelSize: root.wide ? 168 : 112
                font.weight: 650
                lineHeight: 0.82
                color: Colours.fgSurface
                elide: Text.ElideNone
            }

            Row {
                spacing: 14

                Txt {
                    text: Qt.formatDateTime(clock.date, "mm")
                    role: "displayL"
                    font.pixelSize: root.wide ? 168 : 112
                    font.weight: 650
                    lineHeight: 0.82
                    color: Colours.primary
                    elide: Text.ElideNone
                }

                ExprShape {
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: root.wide ? 34 : 22
                    width: root.wide ? 30 : 20
                    height: width
                    shape: root.mood === "busy" ? "sunny" : "cookie6"
                    color: Colours.tertiary
                    rotation: clock.minutes * 6
                }
            }

            Item {
                width: 1
                height: 18
            }

            Txt {
                text: Qt.formatDateTime(clock.date, "dddd d MMMM").toLowerCase()
                role: "titleL"
                font.weight: 500
                color: Colours.fgSurface
                opacity: 0.9
            }
        }

        Glass {
            id: card

            readonly property real centreX: root.wide ? Math.round(parent.width * 0.68) : Math.round(parent.width / 2)

            x: centreX - width / 2
            y: root.wide ? Math.round((parent.height - height) / 2) : Math.max(clockCol.y + clockCol.height + 24, Math.round(parent.height - height - 96))
            width: 420
            height: cardCol.implicitHeight + 64
            radius: Style.rXxl
            scale: (0.94 + 0.06 * Math.min(1, root.enter)) * (1 + 0.06 * root.leave)

            Behavior on height {
                SpringDefault {}
            }

            transform: Translate {
                id: shakeX

                y: (1 - Math.min(1, root.enter)) * 48
            }

            SequentialAnimation {
                id: shakeAnim

                NumberAnimation {
                    target: shakeX
                    property: "x"
                    to: -20
                    duration: 50
                    easing.type: Easing.OutQuad
                }

                SpringAnimation {
                    target: shakeX
                    property: "x"
                    to: 0
                    spring: 9
                    damping: 0.12
                    epsilon: 0.2
                }
            }

            ColumnLayout {
                id: cardCol

                x: 32
                y: 32
                width: parent.width - 64
                spacing: 14

                Item {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 120
                    Layout.preferredHeight: 120

                    ExprShape {
                        anchors.centerIn: parent
                        width: 120
                        height: 120
                        shape: root.mood === "failed" ? "puffy" : root.mood === "busy" ? "sunny" : "softburst"
                        color: Colours.alpha(root.mood === "failed" ? Colours.error : Colours.primary, 0.22)
                        rotation: root.mood === "busy" ? 30 : 0

                        Behavior on rotation {
                            SpringSlow {}
                        }
                    }

                    Avatar {
                        anchors.centerIn: parent
                        width: 100
                        height: 100
                        shape: root.mood === "launching" ? "flower" : root.mood === "failed" ? "clover4" : root.mood === "busy" ? "cookie12" : "cookie9"
                        initial: root.user ? (root.user.display || root.user.name) : ""
                        source: root.user && !Login.demo ? root.user.icon : ""
                        scale: 1 + 0.12 * root.leave
                    }
                }

                Column {
                    Layout.fillWidth: true
                    spacing: 2

                    Txt {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: root.user ? (root.user.display || root.user.name) : "who is signing in"
                        role: "headlineS"
                    }

                    Txt {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        visible: root.user !== null && root.user.display !== ""
                        text: root.user ? root.user.name : ""
                        role: "bodyM"
                        color: Colours.fgSurfaceVariant
                    }
                }

                Row {
                    Layout.alignment: Qt.AlignHCenter
                    visible: Users.list.length > 1
                    spacing: 8

                    Repeater {
                        model: Users.list.slice(0, 7)

                        Item {
                            id: chip

                            required property var modelData
                            readonly property bool current: root.user !== null && root.user.name === modelData.name

                            width: 44
                            height: 44

                            Rectangle {
                                anchors.fill: parent
                                radius: chip.current ? 14 : 22
                                color: "transparent"
                                border.width: 2
                                border.color: chip.current ? Colours.primary : "transparent"

                                Behavior on radius {
                                    SpringFast {}
                                }
                            }

                            Avatar {
                                anchors.centerIn: parent
                                width: 34
                                height: 34
                                shape: chip.current ? "cookie6" : "circle"
                                initial: chip.modelData.display || chip.modelData.name
                                source: Login.demo ? "" : chip.modelData.icon
                                opacity: chip.current ? 1 : 0.7
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.pickUser(chip.modelData.name)
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 56
                    visible: Users.list.length === 0 && !Login.demo
                    radius: height / 2
                    color: Colours.alpha(Colours.surfaceContainerHighest, 0.9)
                    border.width: manualUser.activeFocus ? 2 : 0
                    border.color: Colours.primary

                    TextInput {
                        id: manualUser

                        anchors.fill: parent
                        anchors.leftMargin: 24
                        anchors.rightMargin: 24
                        verticalAlignment: TextInput.AlignVCenter
                        font.family: Style.font
                        font.pixelSize: 16
                        color: Colours.fgSurface
                        maximumLength: 32
                        validator: RegularExpressionValidator {
                            regularExpression: /[a-z_][a-z0-9_-]*\$?/
                        }
                        KeyNavigation.tab: field
                        onAccepted: field.forceActiveFocus()
                    }

                    Txt {
                        anchors.verticalCenter: parent.verticalCenter
                        x: 24
                        visible: manualUser.text.length === 0
                        text: "username"
                        role: "bodyL"
                        color: Colours.fgSurfaceVariant
                    }
                }

                Rectangle {
                    id: pill

                    Layout.fillWidth: true
                    Layout.preferredHeight: 56
                    radius: height / 2
                    color: Colours.alpha(Colours.surfaceContainerHighest, 0.9)
                    border.width: field.activeFocus ? 2 : 0
                    border.color: root.mood === "failed" ? Colours.error : Colours.primary

                    TextInput {
                        id: field

                        readonly property bool reveal: Login.state === "prompt" && Login.promptEcho

                        anchors.fill: parent
                        anchors.leftMargin: 24
                        anchors.rightMargin: 64
                        verticalAlignment: TextInput.AlignVCenter
                        opacity: reveal ? 1 : 0
                        color: Colours.fgSurface
                        font.family: Style.font
                        font.pixelSize: 16
                        echoMode: reveal ? TextInput.Normal : TextInput.Password
                        inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText | Qt.ImhHiddenText | Qt.ImhNoAutoUppercase
                        focus: true
                        enabled: Login.state !== "busy" && Login.state !== "launching"
                        maximumLength: 512
                        onAccepted: root.submit()
                        Keys.onEscapePressed: {
                            if (root.sessionsOpen)
                                root.sessionsOpen = false;
                            else if (Login.state === "prompt")
                                Login.cancel();
                            text = "";
                        }
                        Keys.onUpPressed: root.cycleUser(-1)
                        Keys.onDownPressed: root.cycleUser(1)
                    }

                    Txt {
                        anchors.verticalCenter: parent.verticalCenter
                        x: 24
                        width: parent.width - 88
                        visible: field.text.length === 0
                        text: Login.state === "busy" ? "checking…" : Login.state === "launching" ? "starting your session" : Login.state === "prompt" ? Login.prompt.toLowerCase().replace(/:\s*$/, "") : "password"
                        role: "bodyL"
                        color: Colours.fgSurfaceVariant
                    }

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        x: 24
                        width: parent.width - 88
                        visible: !field.reveal
                        clip: true
                        spacing: 6

                        Repeater {
                            model: Math.min(field.text.length, 18)

                            ExprShape {
                                required property int index

                                width: 14
                                height: 14
                                shape: ["cookie4", "clover4", "cookie6", "flower"][index % 4]
                                color: Colours.primary
                                scale: 0
                                Component.onCompleted: scale = 1

                                Behavior on scale {
                                    SpringFast {}
                                }
                            }
                        }
                    }

                    Item {
                        anchors.right: parent.right
                        anchors.rightMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        width: 44
                        height: 44

                        LoadingIndicator {
                            anchors.fill: parent
                            visible: Login.state === "busy" || Login.state === "launching"
                            color: Colours.primary
                        }

                        IconButton {
                            anchors.fill: parent
                            visible: Login.state !== "busy" && Login.state !== "launching"
                            size: 44
                            variant: "filled"
                            icon: "arrow_forward"
                            onClicked: root.submit()
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 44

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: Math.min(parent.width, sessionRow.implicitWidth + 36)
                        height: 40
                        radius: root.sessionsOpen ? 12 : 20
                        color: root.sessionsOpen ? Colours.secondaryContainer : Colours.alpha(Colours.surfaceContainerHighest, 0.6)
                        visible: Sessions.list.length > 0

                        Behavior on radius {
                            SpringFast {}
                        }

                        Row {
                            id: sessionRow

                            anchors.centerIn: parent
                            spacing: 8

                            Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: root.session && root.session.type === "x11" ? "desktop_windows" : "dashboard"
                                size: 18
                                fill: 1
                                color: Colours.primary
                            }

                            Txt {
                                anchors.verticalCenter: parent.verticalCenter
                                width: Math.min(implicitWidth, 260)
                                text: root.session ? root.session.name : ""
                                role: "labelL"
                                color: root.sessionsOpen ? Colours.fgSecondaryContainer : Colours.fgSurface
                            }

                            Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: Sessions.list.length > 1
                                name: "expand_more"
                                size: 18
                                color: Colours.fgSurfaceVariant
                                rotation: root.sessionsOpen ? 180 : 0

                                Behavior on rotation {
                                    SpringDefault {}
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: Sessions.list.length > 1
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.sessionsOpen = !root.sessionsOpen
                        }
                    }

                    Txt {
                        anchors.centerIn: parent
                        visible: Sessions.list.length === 0 && !Login.demo
                        text: "no desktop sessions found"
                        role: "bodyM"
                        color: Colours.fgSurfaceVariant
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.sessionsOpen ? listCol.implicitHeight : 0
                    clip: true
                    visible: opacity > 0.01
                    opacity: root.sessionsOpen ? 1 : 0

                    Behavior on Layout.preferredHeight {
                        SpringDefault {}
                    }

                    Behavior on opacity {
                        Ease {}
                    }

                    Column {
                        id: listCol

                        width: parent.width
                        spacing: 4

                        Repeater {
                            model: Sessions.list

                            Item {
                                id: srow

                                required property var modelData
                                readonly property bool current: root.session !== null && root.session.id === modelData.id

                                width: listCol.width
                                height: 44

                                Rectangle {
                                    anchors.fill: parent
                                    radius: srow.current ? 22 : 12
                                    color: srow.current ? Colours.primaryContainer : Colours.alpha(Colours.surfaceContainerHighest, 0.5)
                                }

                                Row {
                                    anchors.verticalCenter: parent.verticalCenter
                                    x: 16
                                    spacing: 12

                                    Icon {
                                        anchors.verticalCenter: parent.verticalCenter
                                        name: srow.current ? "check_circle" : srow.modelData.type === "x11" ? "desktop_windows" : "dashboard"
                                        fill: srow.current ? 1 : 0
                                        size: 20
                                        color: srow.current ? Colours.fgPrimaryContainer : Colours.fgSurfaceVariant
                                    }

                                    Txt {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: srow.width - 110
                                        text: srow.modelData.name
                                        role: "bodyL"
                                        color: srow.current ? Colours.fgPrimaryContainer : Colours.fgSurface
                                    }
                                }

                                Txt {
                                    anchors.right: parent.right
                                    anchors.rightMargin: 16
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: srow.modelData.type === "x11" ? "x11" : "wayland"
                                    role: "labelS"
                                    color: srow.current ? Colours.fgPrimaryContainer : Colours.fgSurfaceVariant
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.chosenSession = srow.modelData.id;
                                        root.sessionsOpen = false;
                                        field.forceActiveFocus();
                                    }
                                }
                            }
                        }
                    }
                }

                Txt {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    maximumLineCount: 3
                    text: Login.state === "prompt" ? "" : Login.message
                    visible: text !== ""
                    role: "bodyM"
                    color: Login.state === "failed" || Login.state === "error" ? Colours.error : Colours.fgSurfaceVariant
                }
            }
        }

        RowLayout {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 32
            spacing: 12

            Glass {
                implicitWidth: hostRow.implicitWidth + 32
                implicitHeight: 44
                radius: height / 2
                shadow: false
                visible: root.hostname !== ""

                Row {
                    id: hostRow

                    anchors.verticalCenter: parent.verticalCenter
                    x: 16
                    spacing: 10

                    Icon {
                        name: "computer"
                        size: 20
                        fill: 1
                        color: Colours.primary
                    }

                    Txt {
                        text: root.hostname
                        role: "labelL"
                    }
                }
            }

            Item {
                Layout.fillWidth: true
            }

            Repeater {
                model: [
                    { id: "suspend", icon: "bedtime" },
                    { id: "reboot", icon: "restart_alt" },
                    { id: "poweroff", icon: "power_settings_new" }
                ]

                IconButton {
                    required property var modelData

                    size: 48
                    variant: "tonal"
                    icon: modelData.icon
                    onClicked: root.power(modelData.id)
                }
            }
        }
    }
}
