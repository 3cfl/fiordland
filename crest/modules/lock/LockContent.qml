pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import qs.components
import qs.config
import qs.services
import qs.theme

Item {
    id: root

    property var auth: null
    property bool primary: true
    property real enter: 0
    property real leave: 0
    property bool awake: true
    readonly property string user: Quickshell.env("USER") ?? ""
    readonly property bool live: !Config.demo && Scheme.lockKind !== ""
    readonly property string still: live && Scheme.lockStill !== "" ? Scheme.fileUrl(Scheme.lockStill) : Wallpapers.current
    readonly property bool typing: field.text.length > 0 || root.auth?.state === "busy" || root.auth?.state === "failed"
    readonly property real leaveEase: Math.pow(leave, 2)
    readonly property var notes: Notifs.list.slice(0, 3)

    signal finished

    function seg(a: real, b: real): real {
        const t = Math.max(0, Math.min(1, (enter - a) / (b - a)));
        return 1 - Math.pow(1 - t, 3);
    }

    function wake(): void {
        awake = true;
        doze.restart();
    }

    function shake(): void {
        wake();
        shakeAnim.restart();
        field.text = "";
    }

    function unlock(): void {
        leaveAnim.restart();
    }

    function ago(t: date): string {
        const s = Math.max(0, Math.floor((clock.date.getTime() - t.getTime()) / 1000));
        if (s < 60)
            return "now";
        if (s < 3600)
            return `${Math.floor(s / 60)}m`;
        if (s < 86400)
            return `${Math.floor(s / 3600)}h`;
        return Qt.formatDate(t, "d MMM").toLowerCase();
    }

    Component.onCompleted: enterAnim.start()

    NumberAnimation {
        id: enterAnim

        target: root
        property: "enter"
        from: 0
        to: 1
        duration: Motion.reduced ? 1 : 1200
    }

    NumberAnimation {
        id: leaveAnim

        target: root
        property: "leave"
        to: 1
        duration: Motion.reduced ? 1 : 520
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Motion.standard
        onFinished: root.finished()
    }

    Connections {
        target: root.auth
        ignoreUnknownSignals: true

        function onFailed(): void {
            root.shake();
        }

        function onSucceeded(): void {
            root.unlock();
        }
    }

    Timer {
        id: doze

        interval: 25000
        running: !Config.demo
        onTriggered: {
            if (!root.typing)
                root.awake = false;
        }
    }

    SystemClock {
        id: clock

        precision: SystemClock.Seconds
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.AllButtons
        onPositionChanged: root.wake()
        onPressed: {
            root.wake();
            if (root.primary)
                field.forceActiveFocus();
        }
        onWheel: root.wake()
    }

    Rectangle {
        anchors.fill: parent
        color: Colours.surfaceContainerLowest
    }

    Item {
        id: backdrop

        property real blurTarget: !Style.effects ? 0 : root.typing ? 0.8 : root.awake ? 0.5 : 0.08

        anchors.fill: parent
        scale: 1.07 - 0.07 * root.seg(0, 1)

        Behavior on blurTarget {
            NumberAnimation {
                duration: Motion.durLong
                easing.type: Easing.OutCubic
            }
        }

        Item {
            id: wallLayer

            anchors.fill: parent
            visible: !Style.effects

            Image {
                id: wall

                anchors.fill: parent
                source: root.still
                sourceSize.width: Math.max(1280, root.width)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                smooth: true
            }

            Loader {
                id: video

                anchors.fill: parent
                active: root.live && Scheme.lockVideo !== "" && !(Power.hasBattery && !Power.charging)
                Component.onCompleted: setSource("LockVideo.qml", { source: Scheme.fileUrl(Scheme.lockVideo) })
            }
        }

        MultiEffect {
            anchors.fill: parent
            visible: Style.effects
            source: wallLayer
            autoPaddingEnabled: false
            blurEnabled: true
            blur: backdrop.blurTarget * (1 - root.leaveEase)
            blurMax: 64
            saturation: -0.1 * backdrop.blurTarget * (1 - root.leave)
            brightness: (Colours.light ? 0.02 : -0.12) * backdrop.blurTarget * (1 - root.leave)
        }

        Rectangle {
            anchors.fill: parent
            opacity: (root.awake ? 1 : 0.55) * (1 - root.leave)

            Behavior on opacity {
                NumberAnimation {
                    duration: Motion.durLong
                }
            }

            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: Colours.alpha(Colours.scrim, Colours.light ? 0.16 : 0.42)
                }

                GradientStop {
                    position: 0.35
                    color: Colours.alpha(Colours.scrim, Colours.light ? 0.02 : 0.1)
                }

                GradientStop {
                    position: 0.7
                    color: Colours.alpha(Colours.scrim, Colours.light ? 0.04 : 0.16)
                }

                GradientStop {
                    position: 1
                    color: Colours.alpha(Colours.scrim, Colours.light ? 0.24 : 0.6)
                }
            }
        }
    }

    Item {
        id: clockBox

        readonly property real shown: root.seg(0.05, 0.6)

        anchors.horizontalCenter: parent.horizontalCenter
        width: clockCol.implicitWidth
        height: clockCol.implicitHeight
        y: (root.awake ? root.height * 0.06 : root.height * 0.5 - height / 2 - 20) - 36 * (1 - shown) - 60 * root.leaveEase
        scale: root.awake ? 1 : 1.18
        opacity: shown * (1 - root.leave)

        Behavior on y {
            enabled: root.enter >= 1 && root.leave === 0

            SpringSlow {}
        }

        Behavior on scale {
            SpringSlow {}
        }

        ColumnLayout {
            id: clockCol

            spacing: 2

            Row {
                Layout.alignment: Qt.AlignHCenter
                spacing: 8

                Txt {
                    text: Qt.formatDateTime(clock.date, Config.bar.use24h ? "HH" : "h")
                    role: "displayL"
                    font.pixelSize: Math.min(120, root.height * 0.13)
                    font.weight: 600
                    color: Colours.fgSurface
                    elide: Text.ElideNone
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 16

                    Repeater {
                        model: 2

                        ExprShape {
                            required property int index

                            width: 18
                            height: 18
                            shape: "cookie4"
                            color: index === 0 ? Colours.primary : Colours.tertiary
                            rotation: clock.date.getSeconds() * 6 * (index === 0 ? 1 : -1)

                            Behavior on rotation {
                                SpringDefault {}
                            }
                        }
                    }
                }

                Txt {
                    text: Qt.formatDateTime(clock.date, "mm")
                    role: "displayL"
                    font.pixelSize: Math.min(120, root.height * 0.13)
                    font.weight: 600
                    color: Colours.primary
                    elide: Text.ElideNone
                }
            }

            Txt {
                Layout.alignment: Qt.AlignHCenter
                text: Qt.formatDateTime(clock.date, "dddd d MMMM").toLowerCase()
                role: "titleL"
                font.weight: 500
                color: Colours.fgSurface
                opacity: 0.9
            }
        }
    }

    Item {
        id: stage

        anchors.fill: parent
        visible: root.primary

        Glass {
            id: card

            readonly property real shown: root.seg(0.2, 0.75)

            anchors.centerIn: parent
            anchors.verticalCenterOffset: Math.max(0, root.height * 0.06 + clockBox.height + 28 - (root.height / 2 - height / 2))
            width: 380
            height: cardCol.implicitHeight + 56
            radius: Style.rXxl
            tint: Colours.surfaceContainer
            opacity: shown * (1 - root.leave) * (root.awake ? 1 : 0)
            scale: (0.9 + 0.1 * shown) * (1 - 0.08 * root.leaveEase) * (root.awake ? 1 : 0.94)

            Behavior on height {
                SpringDefault {}
            }

            Behavior on opacity {
                enabled: root.enter >= 1 && root.leave === 0

                NumberAnimation {
                    duration: Motion.durMedium
                }
            }

            Behavior on scale {
                enabled: root.enter >= 1 && root.leave === 0

                SpringDefault {}
            }

            transform: Translate {
                id: shakeX

                y: (1 - card.shown) * 30
            }

            SequentialAnimation {
                id: shakeAnim

                NumberAnimation {
                    target: shakeX
                    property: "x"
                    to: -18
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

                anchors.centerIn: parent
                width: parent.width - 48
                spacing: 14

                Item {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 104
                    Layout.preferredHeight: 104

                    ExprShape {
                        anchors.fill: parent
                        shape: root.auth?.state === "busy" ? "softburst" : "cookie12"
                        color: root.auth?.state === "failed" ? Colours.error : Colours.primary
                        opacity: field.activeFocus ? 0.9 : 0.35
                        rotation: spin.angle

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Motion.durMedium
                            }
                        }
                    }

                    Avatar {
                        anchors.centerIn: parent
                        width: 92
                        height: 92
                        shape: root.auth?.state === "busy" ? "sunny" : root.auth?.state === "failed" ? "puffy" : "cookie9"
                        initial: root.user
                        source: Account.face
                    }

                    QtObject {
                        id: spin

                        property real angle: 0

                        NumberAnimation on angle {
                            from: 0
                            to: 360
                            duration: root.auth?.state === "busy" ? 2400 : 24000
                            loops: Animation.Infinite
                            running: !Motion.reduced && root.primary && root.awake
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Txt {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: root.user || "welcome back"
                        role: "headlineS"
                    }

                    Txt {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: root.auth?.state === "busy" ? "checking…" : root.auth?.state === "maxtries" ? "locked for a moment" : "locked"
                        role: "labelL"
                        color: Colours.fgSurfaceVariant
                    }
                }

                Rectangle {
                    id: pill

                    Layout.fillWidth: true
                    Layout.preferredHeight: 56
                    Layout.topMargin: 4
                    radius: height / 2
                    color: Colours.alpha(Colours.surfaceContainerHighest, 0.92)
                    border.width: field.activeFocus ? 2 : 1
                    border.color: root.auth?.state === "failed" ? Colours.error : field.activeFocus ? Colours.primary : Colours.alpha(Colours.outline, 0.4)

                    Behavior on border.color {
                        ColorAnimation {
                            duration: Motion.durShort
                        }
                    }

                    TextInput {
                        id: field

                        anchors.fill: parent
                        anchors.leftMargin: 24
                        anchors.rightMargin: 60
                        opacity: 0
                        echoMode: TextInput.Password
                        inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText | Qt.ImhHiddenText
                        focus: root.primary
                        enabled: root.auth?.state !== "maxtries" && root.auth?.state !== "ok"
                        onAccepted: {
                            if (root.auth && text.length > 0)
                                root.auth.submit(text);
                            text = "";
                        }
                        onTextChanged: root.wake()
                        Keys.onPressed: event => {
                            root.wake();
                            event.accepted = false;
                        }
                        Keys.onEscapePressed: text = ""
                        Component.onCompleted: if (root.primary) Qt.callLater(forceActiveFocus)
                        onEnabledChanged: if (enabled && root.primary) forceActiveFocus()
                        onActiveFocusChanged: if (!activeFocus && enabled && root.primary) Qt.callLater(forceActiveFocus)
                    }

                    Connections {
                        target: root.Window.window

                        function onActiveChanged(): void {
                            if (root.Window.window?.active && field.enabled && root.primary)
                                field.forceActiveFocus();
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.IBeamCursor
                        onPressed: mouse => {
                            field.forceActiveFocus();
                            mouse.accepted = false;
                        }
                    }

                    Txt {
                        anchors.verticalCenter: parent.verticalCenter
                        x: 24
                        opacity: field.text.length === 0 ? 1 : 0
                        text: root.auth?.fprintReady && Config.lock.fingerprint ? "password or fingerprint" : "password"
                        role: "bodyL"
                        color: Colours.fgSurfaceVariant

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Motion.durShort
                            }
                        }
                    }

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        x: 24
                        width: parent.width - 84
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
                                rotation: -90
                                Component.onCompleted: {
                                    scale = 1;
                                    rotation = 0;
                                }

                                Behavior on scale {
                                    SpringFast {}
                                }

                                Behavior on rotation {
                                    SpringDefault {}
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
                            visible: root.auth?.state === "busy"
                            color: Colours.primary
                        }

                        IconButton {
                            anchors.fill: parent
                            visible: root.auth?.state !== "busy"
                            size: 44
                            variant: field.text.length > 0 ? "filled" : "tonal"
                            icon: root.auth?.fprintReady && field.text.length === 0 ? "fingerprint" : "arrow_forward"
                            onClicked: field.accepted()
                        }
                    }
                }

                Txt {
                    Layout.fillWidth: true
                    Layout.preferredHeight: text ? 20 : 0
                    Layout.topMargin: text ? 0 : -14
                    horizontalAlignment: Text.AlignHCenter
                    text: root.auth?.message ?? ""
                    role: "bodyM"
                    color: Colours.error
                    opacity: text ? 1 : 0

                    Behavior on opacity {
                        Ease {}
                    }
                }
            }
        }

        Glass {
            id: player

            readonly property real shown: root.seg(0.35, 0.9)
            readonly property bool has: Media.available && Media.title !== ""

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: card.bottom
            anchors.topMargin: 16
            width: 380
            height: 84
            radius: Style.rXl
            visible: has
            clip: true
            opacity: shown * (1 - root.leave) * (root.awake ? 1 : 0)

            Behavior on opacity {
                enabled: root.enter >= 1 && root.leave === 0

                NumberAnimation {
                    duration: Motion.durMedium
                }
            }

            transform: Translate {
                y: (1 - player.shown) * 40 + 20 * root.leaveEase
            }

            Component.onCompleted: Media.trackers++
            Component.onDestruction: Media.trackers--

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 10
                spacing: 12

                Avatar {
                    id: art

                    Layout.preferredWidth: 56
                    Layout.preferredHeight: 56
                    source: Media.art
                    shape: Media.playing ? "cookie12" : "circle"
                    initial: Media.title
                    rotation: discSpin.angle

                    QtObject {
                        id: discSpin

                        property real angle: 0

                        NumberAnimation on angle {
                            from: 0
                            to: 360
                            duration: 16000
                            loops: Animation.Infinite
                            running: !Motion.reduced && Media.playing && player.visible && root.awake
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Txt {
                        Layout.fillWidth: true
                        text: Media.title
                        role: "titleS"
                    }

                    Txt {
                        Layout.fillWidth: true
                        text: Media.artist || Media.identity
                        role: "bodyM"
                        color: Colours.fgSurfaceVariant
                    }

                    WavyLine {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 10
                        Layout.topMargin: 4
                        value: Media.progress
                        animating: Media.playing && root.awake
                        amplitude: Media.playing ? 2 : 0
                        thickness: 3
                        trackColor: Colours.alpha(Colours.fgSurface, 0.16)
                    }
                }

                IconButton {
                    size: 36
                    icon: "skip_previous"
                    onClicked: Media.previous()
                }

                IconButton {
                    size: 44
                    variant: "filled"
                    icon: Media.playing ? "pause" : "play_arrow"
                    onClicked: Media.toggle()
                }

                IconButton {
                    size: 36
                    icon: "skip_next"
                    onClicked: Media.next()
                }
            }
        }

        Column {
            id: notesCol

            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.margins: 32
            width: 340
            spacing: 8
            visible: Notifs.count > 0
            opacity: (1 - root.leave) * (root.awake ? 1 : 0.7)

            Behavior on opacity {
                enabled: root.enter >= 1 && root.leave === 0

                NumberAnimation {
                    duration: Motion.durMedium
                }
            }

            Row {
                spacing: 8
                opacity: root.seg(0.4, 0.85)
                leftPadding: 6

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "notifications"
                    size: 18
                    fill: 1
                    color: Colours.primary
                }

                Txt {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Notifs.count === 1 ? "1 notification" : `${Notifs.count} notifications`
                    role: "labelL"
                    color: Colours.fgSurface
                }
            }

            Repeater {
                model: root.notes

                Glass {
                    id: note

                    required property var modelData
                    required property int index
                    readonly property real shown: root.seg(0.45 + index * 0.08, 0.9 + index * 0.03)

                    width: notesCol.width
                    height: 60
                    radius: Style.rXl
                    shadow: false
                    opacity: shown
                    transform: Translate {
                        x: (1 - note.shown) * -40
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 16
                        spacing: 12

                        Item {
                            Layout.preferredWidth: 32
                            Layout.preferredHeight: 32

                            Rectangle {
                                anchors.fill: parent
                                radius: width / 2
                                color: Colours.secondaryContainer
                                visible: noteIcon.status !== Image.Ready
                            }

                            Icon {
                                anchors.centerIn: parent
                                visible: noteIcon.status !== Image.Ready
                                name: "notifications"
                                size: 18
                                color: Colours.fgSecondaryContainer
                            }

                            Image {
                                id: noteIcon

                                anchors.fill: parent
                                source: note.modelData.appIcon ? Quickshell.iconPath(note.modelData.appIcon, true) : ""
                                sourceSize.width: 64
                                sourceSize.height: 64
                                asynchronous: true
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                Txt {
                                    Layout.fillWidth: true
                                    text: note.modelData.appName || "notification"
                                    role: "labelM"
                                    color: Colours.fgSurfaceVariant
                                }

                                Txt {
                                    text: root.ago(note.modelData.time)
                                    role: "labelM"
                                    color: Colours.fgSurfaceVariant
                                }
                            }

                            Txt {
                                Layout.fillWidth: true
                                text: note.modelData.summary
                                role: "bodyM"
                                font.weight: 500
                            }
                        }
                    }
                }
            }
        }

        RowLayout {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 32
            spacing: 10
            opacity: root.seg(0.5, 1) * (1 - root.leave)

            Chip {
                visible: Power.hasBattery
                icon: Power.icon
                text: `${Math.round(Power.level * 100)}%`
            }

            IconButton {
                size: 48
                variant: "tonal"
                icon: "bedtime"
                onClicked: Session.run("suspend")
            }

            IconButton {
                size: 48
                variant: "tonal"
                icon: "power_settings_new"
                onClicked: Session.run("poweroff")
            }
        }
    }

    component Chip: Glass {
        id: chip

        property string icon
        property string text

        implicitWidth: chipRow.implicitWidth + 32
        implicitHeight: 48
        radius: height / 2
        shadow: false

        Row {
            id: chipRow

            anchors.verticalCenter: parent.verticalCenter
            x: 16
            spacing: 8

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: chip.icon
                size: 20
                fill: 1
                color: Colours.primary
            }

            Txt {
                anchors.verticalCenter: parent.verticalCenter
                text: chip.text
                role: "labelL"
            }
        }
    }
}
