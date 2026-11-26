pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.components
import qs.services
import qs.theme

ColumnLayout {
    id: root

    readonly property var req: Bt.request
    readonly property string kind: req?.kind ?? ""
    readonly property string who: req?.name || req?.address || "a device"
    readonly property bool input: kind === "pin" || kind === "passkey"
    readonly property bool asking: kind === "authorize" || kind === "service"
    property bool invalid: false

    function title(): string {
        if (req?.display)
            return `type this on ${who}`;
        if (kind === "confirm")
            return `pair with ${who}?`;
        if (kind === "authorize")
            return `${who} wants to pair`;
        if (kind === "service")
            return `${who} wants to connect`;
        if (kind === "pin")
            return `PIN for ${who}`;
        return `code for ${who}`;
    }

    function body(): string {
        if (req?.display)
            return "then press enter on it";
        if (kind === "confirm")
            return "check it shows the same code";
        if (kind === "authorize")
            return "let it pair with this computer?";
        if (kind === "service")
            return `it isn't paired yet. allow ${Bt.serviceName(req?.uuid ?? "")}?`;
        if (kind === "pin")
            return "often 0000 or 1234, or check its manual";
        return "type the 6 digit code it shows";
    }

    function send(): void {
        if (input) {
            if (Bt.submit(field.text))
                field.text = "";
            else
                shake.restart();
        } else {
            Bt.accept();
        }
    }

    spacing: 14

    Keys.onEscapePressed: Bt.reject()
    Keys.onReturnPressed: send()
    Keys.onEnterPressed: send()

    RowLayout {
        Layout.fillWidth: true
        spacing: 14

        Item {
            Layout.preferredWidth: 56
            Layout.preferredHeight: 56

            ExprShape {
                anchors.fill: parent
                shape: root.req?.display ? "sunny" : root.asking ? "clover8" : "cookie12"
                color: Colours.primary
                segments: 120

                RotationAnimator on rotation {
                    running: root.visible && !Motion.reduced
                    from: 0
                    to: 360
                    duration: 12000
                    loops: Animation.Infinite
                }
            }

            Icon {
                anchors.centerIn: parent
                name: Bt.icon(root.req?.icon ?? "")
                fill: 1
                size: 26
                color: Colours.fgPrimary
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Txt {
                Layout.fillWidth: true
                text: root.title()
                role: "titleM"
            }

            Txt {
                Layout.fillWidth: true
                text: root.body()
                role: "bodyM"
                color: Colours.fgSurfaceVariant
                wrapMode: Text.WordWrap
                elide: Text.ElideNone
            }
        }
    }

    Row {
        Layout.alignment: Qt.AlignHCenter
        visible: (root.req?.code ?? "") !== ""
        spacing: 6

        Repeater {
            model: (root.req?.code ?? "").split("")

            Rectangle {
                id: digit

                required property string modelData
                required property int index
                readonly property bool typed: root.req?.display === true && index < (root.req?.entered ?? 0)
                property real pop: 0

                width: 40
                height: 52
                radius: typed ? 20 : Style.rMd
                color: typed ? Colours.primary : Colours.alpha(Colours.surfaceContainerHighest, 0.9)
                scale: 0.6 + 0.4 * pop
                opacity: pop

                Component.onCompleted: popIn.start()

                Behavior on radius {
                    SpringFast {}
                }

                Behavior on color {
                    ColorEase {}
                }

                SequentialAnimation {
                    id: popIn

                    PauseAnimation {
                        duration: Motion.reduced ? 0 : digit.index * 45
                    }

                    SpringAnimation {
                        target: digit
                        property: "pop"
                        to: 1
                        spring: Motion.fastSpring
                        damping: Motion.fastDamping
                        epsilon: 0.01
                    }
                }

                Txt {
                    anchors.centerIn: parent
                    text: digit.modelData
                    role: "headlineM"
                    color: digit.typed ? Colours.fgPrimary : Colours.fgSurface
                }
            }
        }
    }

    Rectangle {
        id: fieldBox

        Layout.fillWidth: true
        Layout.preferredHeight: 48
        visible: root.input
        radius: height / 2
        color: Colours.surfaceContainerLowest
        border.width: root.invalid ? 2 : 0
        border.color: Colours.error

        transform: Translate {
            id: nudge
        }

        SequentialAnimation {
            id: shake

            ScriptAction {
                script: root.invalid = true
            }

            NumberAnimation {
                target: nudge
                property: "x"
                to: 10
                duration: Motion.reduced ? 1 : 50
            }

            SpringAnimation {
                target: nudge
                property: "x"
                to: 0
                spring: Motion.fastSpring
                damping: 0.12
                epsilon: 0.2
            }
        }

        Icon {
            id: keyIcon

            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            name: "password"
            size: 20
            color: root.invalid ? Colours.error : Colours.fgSurfaceVariant
        }

        TextInput {
            id: field

            anchors.fill: parent
            anchors.leftMargin: 48
            anchors.rightMargin: 16
            verticalAlignment: TextInput.AlignVCenter
            color: Colours.fgSurface
            font.family: Style.font
            font.pixelSize: 16
            font.letterSpacing: 2
            maximumLength: root.kind === "passkey" ? 6 : 16
            inputMethodHints: root.kind === "passkey" ? Qt.ImhDigitsOnly : Qt.ImhNoPredictiveText
            focus: root.input && root.visible
            onTextEdited: root.invalid = false
            onAccepted: root.send()
            Keys.onEscapePressed: Bt.reject()

            Txt {
                anchors.fill: parent
                visible: field.text === ""
                text: root.kind === "passkey" ? "6 digit code" : "PIN"
                role: "bodyL"
                color: Colours.fgSurfaceVariant
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Item {
            Layout.fillWidth: true
        }

        PillButton {
            text: root.req?.display ? "hide" : root.asking ? "deny" : "cancel"
            variant: "text"
            onClicked: Bt.reject()
        }

        PillButton {
            visible: !root.req?.display
            text: root.asking ? "allow" : "pair"
            icon: root.asking ? "check" : "link"
            variant: "filled"
            onClicked: root.send()
        }
    }
}
