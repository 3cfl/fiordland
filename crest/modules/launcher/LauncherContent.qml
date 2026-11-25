pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.components
import qs.services
import qs.theme
import "../../utils/calc.js" as Calc

Glass {
    id: root

    property string seed: ""
    readonly property string text: field.text
    readonly property string mode: text.startsWith(":") ? "emoji" : (text.startsWith("=") ? "calc" : "apps")
    readonly property string query: mode === "apps" ? text : text.slice(1)
    readonly property string answer: mode === "emoji" ? "" : (Calc.evaluate(text, mode === "calc") ?? "")
    readonly property var apps: mode === "apps" ? Apps.query(query, 8) : []
    readonly property var emoji: mode === "emoji" ? Emoji.query(query, 48) : []
    readonly property int count: mode === "emoji" ? emoji.length : apps.length
    property int current: 0

    signal done

    implicitWidth: 640
    implicitHeight: column.implicitHeight + 24
    radius: Style.rXxl

    onTextChanged: current = 0
    onModeChanged: {
        if (mode === "emoji")
            Emoji.load();
    }

    Behavior on implicitHeight {
        SpringDefault {}
    }

    Component.onCompleted: {
        field.text = seed;
        field.forceActiveFocus();
    }

    function move(step: int): void {
        if (count > 0)
            current = (current + step + count) % count;
    }

    function activate(): void {
        if (answer !== "" && (mode === "calc" || count === 0)) {
            Quickshell.execDetached(["wl-copy", "--", answer]);
            done();
        } else if (mode === "emoji" && emoji[current]) {
            Emoji.copy(emoji[current]);
            done();
        } else if (mode === "apps" && apps[current]) {
            Apps.launch(apps[current]);
            done();
        }
    }

    ColumnLayout {
        id: column

        x: 12
        y: 12
        width: parent.width - 24
        spacing: 8

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 60
            radius: height / 2
            color: Colours.alpha(Colours.surfaceContainerHighest, 0.9)

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 18
                spacing: 12

                Item {
                    Layout.preferredWidth: 40
                    Layout.preferredHeight: 40

                    ExprShape {
                        anchors.fill: parent
                        shape: root.mode === "calc" ? "cookie4" : root.mode === "emoji" ? "flower" : "cookie9"
                        color: Colours.primary
                    }

                    Icon {
                        anchors.centerIn: parent
                        name: root.mode === "calc" ? "calculate" : root.mode === "emoji" ? "mood" : "search"
                        size: 22
                        fill: 1
                        color: Colours.fgPrimary
                    }
                }

                TextInput {
                    id: field

                    Layout.fillWidth: true
                    color: Colours.fgSurface
                    selectionColor: Colours.primary
                    selectedTextColor: Colours.fgPrimary
                    font.family: Style.font
                    font.pixelSize: 18
                    clip: true
                    focus: true

                    Keys.onDownPressed: root.move(root.mode === "emoji" ? 8 : 1)
                    Keys.onUpPressed: root.move(root.mode === "emoji" ? -8 : -1)
                    Keys.onRightPressed: event => {
                        if (root.mode === "emoji")
                            root.move(1);
                        else
                            event.accepted = false;
                    }
                    Keys.onLeftPressed: event => {
                        if (root.mode === "emoji")
                            root.move(-1);
                        else
                            event.accepted = false;
                    }
                    Keys.onTabPressed: root.move(1)
                    Keys.onBacktabPressed: root.move(-1)
                    Keys.onReturnPressed: root.activate()
                    Keys.onEnterPressed: root.activate()
                    Keys.onEscapePressed: root.done()

                    Txt {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: field.text === ""
                        text: "search apps, = to calculate, : for emoji"
                        role: "bodyL"
                        font.pixelSize: 17
                        color: Colours.fgSurfaceVariant
                    }
                }

                Rectangle {
                    visible: root.mode !== "apps"
                    Layout.preferredHeight: 28
                    Layout.preferredWidth: chip.implicitWidth + 20
                    radius: 14
                    color: Colours.tertiaryContainer

                    Txt {
                        id: chip

                        anchors.centerIn: parent
                        text: root.mode === "calc" ? "calculator" : "emoji"
                        role: "labelM"
                        color: Colours.fgTertiaryContainer
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 84
            visible: root.answer !== ""
            radius: Style.rXl
            color: Colours.primaryContainer

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 24
                anchors.rightMargin: 16
                spacing: 12

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Txt {
                        Layout.fillWidth: true
                        text: root.query.trim()
                        role: "bodyM"
                        color: Colours.fgPrimaryContainer
                        opacity: 0.75
                    }

                    Txt {
                        Layout.fillWidth: true
                        text: "= " + root.answer
                        role: "headlineM"
                        color: Colours.fgPrimaryContainer
                    }
                }

                PillButton {
                    text: "copy"
                    icon: "content_copy"
                    variant: "filled"
                    onClicked: {
                        Quickshell.execDetached(["wl-copy", "--", root.answer]);
                        root.done();
                    }
                }
            }
        }

        Repeater {
            model: root.apps

            Item {
                id: row

                required property var modelData
                required property int index
                readonly property bool selected: index === root.current

                Layout.fillWidth: true
                Layout.preferredHeight: 60

                Rectangle {
                    anchors.fill: parent
                    radius: row.selected ? Style.rXl : Style.rLg
                    color: row.selected ? Colours.secondaryContainer : "transparent"

                    Behavior on radius {
                        SpringFast {}
                    }

                    Behavior on color {
                        ColorEase {}
                    }

                    StateLayer {
                        radius: parent.radius
                        onEntered: root.current = row.index
                        onClicked: {
                            root.current = row.index;
                            root.activate();
                        }
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 16
                    spacing: 14

                    Item {
                        Layout.preferredWidth: 40
                        Layout.preferredHeight: 40

                        Rectangle {
                            anchors.fill: parent
                            radius: Style.rMd
                            visible: icon.status !== Image.Ready
                            color: Colours.tertiaryContainer

                            Txt {
                                anchors.centerIn: parent
                                text: (row.modelData.name ?? "?").charAt(0).toUpperCase()
                                role: "titleM"
                                color: Colours.fgTertiaryContainer
                            }
                        }

                        IconImage {
                            id: icon

                            anchors.fill: parent
                            source: Apps.icon(row.modelData.icon ?? "")
                            asynchronous: true
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Txt {
                            Layout.fillWidth: true
                            text: row.modelData.name ?? ""
                            role: "titleM"
                            color: row.selected ? Colours.fgSecondaryContainer : Colours.fgSurface
                        }

                        Txt {
                            Layout.fillWidth: true
                            visible: text !== ""
                            text: row.modelData.comment || row.modelData.genericName || ""
                            role: "bodyS"
                            color: row.selected ? Colours.fgSecondaryContainer : Colours.fgSurfaceVariant
                        }
                    }

                    Icon {
                        visible: row.selected
                        name: "keyboard_return"
                        size: 18
                        color: Colours.fgSecondaryContainer
                    }
                }
            }
        }

        GridLayout {
            Layout.fillWidth: true
            visible: root.mode === "emoji"
            columns: 8
            rowSpacing: 4
            columnSpacing: 4

            Repeater {
                model: root.emoji

                Rectangle {
                    id: cell

                    required property var modelData
                    required property int index
                    readonly property bool selected: index === root.current

                    Layout.fillWidth: true
                    Layout.preferredHeight: 64
                    radius: selected ? Style.rXl : Style.rLg
                    color: selected ? Colours.secondaryContainer : Colours.alpha(Colours.surfaceContainerHighest, 0.4)

                    Behavior on radius {
                        SpringFast {}
                    }

                    Text {
                        anchors.centerIn: parent
                        text: cell.modelData.char
                        font.pixelSize: 30
                        font.family: "Noto Color Emoji"
                    }

                    StateLayer {
                        radius: parent.radius
                        onEntered: root.current = cell.index
                        onClicked: {
                            root.current = cell.index;
                            root.activate();
                        }
                    }
                }
            }
        }

        Txt {
            Layout.fillWidth: true
            Layout.leftMargin: 16
            visible: root.mode === "emoji" && root.emoji[root.current] !== undefined
            text: root.emoji[root.current]?.name ?? ""
            role: "labelM"
            color: Colours.fgSurfaceVariant
        }

        Txt {
            Layout.fillWidth: true
            Layout.preferredHeight: 52
            visible: root.count === 0 && root.answer === "" && root.text !== ""
            horizontalAlignment: Text.AlignHCenter
            text: root.mode === "emoji" && !Emoji.ready ? "loading emoji…" : "nothing matches"
            role: "bodyM"
            color: Colours.fgSurfaceVariant
        }
    }
}
