pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.components
import qs.services
import qs.theme

ColumnLayout {
    id: root

    property string view: "history"
    property int current: 0
    readonly property string query: field.text.toLowerCase()
    readonly property var items: {
        const src = view === "history" ? Clip.entries : Clip.favourites;
        if (query === "")
            return src;
        return src.filter(e => (e.text ?? "").toLowerCase().includes(query) || (e.meta ?? "").toLowerCase().includes(query));
    }

    signal done

    spacing: 12

    onItemsChanged: current = Math.min(current, Math.max(0, items.length - 1))
    onViewChanged: current = 0

    Component.onCompleted: {
        Clip.refresh();
        field.forceActiveFocus();
    }

    function move(step: int): void {
        if (items.length > 0)
            current = (current + step + items.length) % items.length;
        list.positionViewAtIndex(current, ListView.Contain);
    }

    function pick(entry: var): void {
        Clip.copy(entry);
        done();
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 10

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 48
            radius: 24
            color: Colours.alpha(Colours.surfaceContainerHighest, 0.7)

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                spacing: 10

                Icon {
                    name: "search"
                    size: 20
                    color: Colours.fgSurfaceVariant
                }

                TextInput {
                    id: field

                    Layout.fillWidth: true
                    color: Colours.fgSurface
                    selectionColor: Colours.primary
                    selectedTextColor: Colours.fgPrimary
                    font.family: Style.font
                    font.pixelSize: 16
                    clip: true
                    focus: true

                    Keys.onDownPressed: root.move(1)
                    Keys.onUpPressed: root.move(-1)
                    Keys.onTabPressed: root.view = root.view === "history" ? "favourites" : "history"
                    Keys.onReturnPressed: root.pick(root.items[root.current])
                    Keys.onEnterPressed: root.pick(root.items[root.current])
                    Keys.onEscapePressed: root.done()
                    Keys.onPressed: event => {
                        if (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_S) {
                            Clip.toggleFavourite(root.items[root.current]);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Delete && root.view === "history") {
                            Clip.remove(root.items[root.current]);
                            event.accepted = true;
                        }
                    }

                    Txt {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: field.text === ""
                        text: root.view === "history" ? "search clipboard" : "search favourites"
                        role: "bodyL"
                        color: Colours.fgSurfaceVariant
                    }
                }
            }
        }

        Segmented {
            size: 48
            options: [
                { id: "history", icon: "history", label: "" },
                { id: "favourites", icon: "star", label: "" }
            ]
            current: root.view
            onPicked: id => root.view = id
        }

        IconButton {
            visible: root.view === "history"
            size: 48
            icon: "delete_sweep"
            variant: "tonal"
            enabled: Clip.entries.length > 0
            onClicked: Clip.wipe()
        }
    }

    Item {
        Layout.fillWidth: true
        Layout.preferredHeight: 380

        ListView {
            id: list

            anchors.fill: parent
            clip: true
            spacing: 6
            model: root.items
            currentIndex: root.current
            boundsBehavior: Flickable.StopAtBounds
            highlightFollowsCurrentItem: false

            add: Transition {
                NumberAnimation {
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: Motion.durShort
                }
            }

            delegate: Rectangle {
                id: row

                required property var modelData
                required property int index
                readonly property bool fav: !!modelData.kind
                readonly property bool image: fav ? modelData.kind === "image" : modelData.image
                readonly property bool selected: index === root.current
                readonly property bool starred: fav || (!image && Clip.isFavourite(modelData.text))

                width: list.width
                height: image ? 92 : (textBody.lineCount > 1 ? 70 : 52)
                radius: selected ? Style.rLg : Style.rMd
                color: selected ? Colours.secondaryContainer : Colours.alpha(Colours.surfaceContainerHighest, 0.55)

                Behavior on radius {
                    SpringFast {}
                }

                Behavior on color {
                    ColorEase {}
                }

                StateLayer {
                    radius: row.radius
                    tint: Colours.fgSurface
                    onClicked: root.pick(row.modelData)
                    onEntered: root.current = row.index
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 8
                    spacing: 12

                    Rectangle {
                        visible: row.image
                        Layout.preferredWidth: 120
                        Layout.preferredHeight: 72
                        radius: Style.rSm
                        color: Colours.surfaceContainer
                        clip: true

                        Image {
                            anchors.fill: parent
                            source: row.image ? (row.fav ? `file://${row.modelData.file}` : Clip.thumb(row.modelData.id)) : ""
                            sourceSize.width: 240
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: false
                        }
                    }

                    Icon {
                        visible: !row.image
                        name: /^https?:\/\//.test(row.modelData.text ?? "") ? "link" : (row.modelData.text ?? "").includes("\n") ? "notes" : "content_copy"
                        size: 20
                        color: row.selected ? Colours.fgSecondaryContainer : Colours.fgSurfaceVariant
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Txt {
                            id: textBody

                            Layout.fillWidth: true
                            text: row.image ? "image" : (row.modelData.text ?? "").trim().replace(/\s*\n\s*/g, " ↵ ")
                            role: row.image ? "labelL" : "bodyM"
                            wrapMode: Text.WrapAnywhere
                            maximumLineCount: 2
                            color: row.selected ? Colours.fgSecondaryContainer : Colours.fgSurface
                        }

                        Txt {
                            visible: row.image
                            text: row.modelData.meta ?? ""
                            role: "labelS"
                            color: Colours.fgSurfaceVariant
                        }
                    }

                    IconButton {
                        size: 36
                        iconSize: 20
                        icon: "star"
                        checkable: true
                        checked: row.starred
                        onClicked: Clip.toggleFavourite(row.modelData)
                    }

                    IconButton {
                        visible: !row.fav
                        size: 36
                        iconSize: 20
                        icon: "close"
                        onClicked: Clip.remove(row.modelData)
                    }
                }
            }
        }

        ColumnLayout {
            anchors.centerIn: parent
            visible: root.items.length === 0
            spacing: 10

            Item {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 72
                Layout.preferredHeight: 72

                ExprShape {
                    anchors.fill: parent
                    shape: root.view === "history" ? "cookie6" : "sunny"
                    color: Colours.secondaryContainer
                }

                Icon {
                    anchors.centerIn: parent
                    name: !Clip.available && Clip.probed ? "error" : root.view === "history" ? "content_paste_off" : "star"
                    size: 30
                    color: Colours.fgSecondaryContainer
                }
            }

            Txt {
                Layout.alignment: Qt.AlignHCenter
                text: !Clip.available && Clip.probed ? "cliphist isn't installed" : root.query !== "" ? "no matches" : root.view === "history" ? "nothing copied yet" : "no favourites yet"
                role: "titleM"
            }

            Txt {
                Layout.alignment: Qt.AlignHCenter
                text: !Clip.available && Clip.probed ? "install cliphist to keep clipboard history" : root.view === "history" ? "anything you copy shows up here" : "star something in history to keep it here"
                role: "bodyS"
                color: Colours.fgSurfaceVariant
            }
        }
    }

    Txt {
        Layout.alignment: Qt.AlignHCenter
        text: "enter copies · ctrl+s favourites · del removes · tab switches"
        role: "labelS"
        color: Colours.fgSurfaceVariant
    }
}
