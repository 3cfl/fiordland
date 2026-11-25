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
    readonly property string user: Quickshell.env("USER") ?? ""

    signal finished

    Component.onCompleted: enter = 1

    Behavior on enter {
        SpringSlow {}
    }

    function shake(): void {
        shakeAnim.restart();
        field.text = "";
    }

    function unlock(): void {
        leaveAnim.restart();
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

    NumberAnimation {
        id: leaveAnim

        target: root
        property: "leave"
        to: 1
        duration: Motion.durMedium
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Motion.emphasizedAccel
        onFinished: root.finished()
    }

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    Rectangle {
        anchors.fill: parent
        color: Colours.surfaceContainerLowest
    }

    Item {
        id: backdrop

        anchors.fill: parent
        opacity: 1 - root.leave

        Image {
            id: wall

            anchors.fill: parent
            source: Wallpapers.current
            sourceSize.width: Style.effects ? 1280 : 160
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: !Style.effects
            smooth: true
        }

        MultiEffect {
            anchors.fill: parent
            visible: Style.effects
            source: wall
            blurEnabled: true
            blur: 1
            blurMax: 64
            saturation: 0.15
            brightness: Colours.light ? 0.05 : -0.1
        }

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: Colours.alpha(Colours.scrim, Colours.light ? 0.05 : 0.15)
                }

                GradientStop {
                    position: 1
                    color: Colours.alpha(Colours.scrim, Colours.light ? 0.25 : 0.55)
                }
            }
        }
    }

    Item {
        id: stage

        anchors.fill: parent
        visible: root.primary
        opacity: Math.min(1, root.enter) * (1 - root.leave)
        scale: (0.96 + 0.04 * root.enter) * (1 + 0.04 * root.leave)

        ColumnLayout {
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * 0.13
            spacing: 0

            Row {
                Layout.alignment: Qt.AlignHCenter
                spacing: 6

                Txt {
                    text: Qt.formatDateTime(clock.date, Config.bar.use24h ? "HH" : "h")
                    role: "displayL"
                    font.pixelSize: 148
                    font.weight: 600
                    color: Colours.fgSurface
                    elide: Text.ElideNone
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 18

                    ExprShape {
                        width: 20
                        height: 20
                        shape: "cookie4"
                        color: Colours.primary
                    }

                    ExprShape {
                        width: 20
                        height: 20
                        shape: "cookie4"
                        color: Colours.tertiary
                    }
                }

                Txt {
                    text: Qt.formatDateTime(clock.date, "mm")
                    role: "displayL"
                    font.pixelSize: 148
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
                opacity: 0.85
            }
        }

        Glass {
            id: card

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: parent.height * 0.14
            width: 400
            height: cardCol.implicitHeight + 56
            radius: Style.rXxl

            transform: Translate {
                id: shakeX

                y: (1 - Math.min(1, root.enter)) * 40
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
                width: parent.width - 56
                spacing: 16

                Avatar {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 96
                    Layout.preferredHeight: 96
                    shape: root.auth?.state === "busy" ? "sunny" : root.auth?.state === "failed" ? "puffy" : "cookie9"
                    initial: root.user
                    source: Config.demo ? "" : `file://${Config.home}/.face`
                }

                Txt {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.user || "welcome back"
                    role: "headlineS"
                }

                Rectangle {
                    id: pill

                    Layout.fillWidth: true
                    Layout.preferredHeight: 56
                    radius: height / 2
                    color: Colours.alpha(Colours.surfaceContainerHighest, 0.9)
                    border.width: field.activeFocus ? 2 : 0
                    border.color: root.auth?.state === "failed" ? Colours.error : Colours.primary

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
                        Keys.onEscapePressed: text = ""
                    }

                    Txt {
                        anchors.verticalCenter: parent.verticalCenter
                        x: 24
                        visible: field.text.length === 0
                        text: root.auth?.state === "busy" ? "checking…" : root.auth?.fprintReady && Config.lock.fingerprint ? "password or fingerprint" : "password"
                        role: "bodyL"
                        color: Colours.fgSurfaceVariant
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
                            visible: root.auth?.state === "busy"
                            color: Colours.primary
                        }

                        IconButton {
                            anchors.fill: parent
                            visible: root.auth?.state !== "busy"
                            size: 44
                            variant: "filled"
                            icon: root.auth?.fprintReady && field.text.length === 0 ? "fingerprint" : "arrow_forward"
                            onClicked: field.accepted()
                        }
                    }
                }

                Txt {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 20
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

        RowLayout {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 32
            spacing: 12

            Chip {
                visible: Power.hasBattery
                icon: Power.icon
                text: `${Math.round(Power.level * 100)}%`
            }

            Chip {
                visible: Media.available && Media.title !== ""
                icon: Media.playing ? "graphic_eq" : "music_note"
                text: Media.artist ? `${Media.title} · ${Media.artist}` : Media.title
            }

            Item {
                Layout.fillWidth: true
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

        implicitWidth: Math.min(360, chipRow.implicitWidth + 32)
        implicitHeight: 44
        radius: height / 2
        shadow: false

        Row {
            id: chipRow

            anchors.verticalCenter: parent.verticalCenter
            x: 16
            spacing: 10

            Icon {
                name: chip.icon
                size: 20
                fill: 1
                color: Colours.primary
            }

            Txt {
                width: Math.min(implicitWidth, 290)
                text: chip.text
                role: "labelL"
            }
        }
    }
}
