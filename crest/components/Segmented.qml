pragma ComponentBehavior: Bound

import QtQuick
import qs.theme

Row {
    id: root

    property var options: []
    property string current: ""
    property int size: 40

    signal picked(string id)

    spacing: 2

    Repeater {
        model: root.options

        Rectangle {
            id: seg

            required property var modelData
            required property int index
            readonly property bool selected: root.current === modelData.id
            readonly property bool first: index === 0
            readonly property bool last: index === root.options.length - 1
            readonly property real outer: height / 2
            readonly property real inner: selected ? height / 2 : Style.rSm

            implicitWidth: Math.max(root.size * 1.3, content.implicitWidth + 32)
            implicitHeight: root.size
            color: selected ? Colours.secondaryContainer : Colours.alpha(Colours.surfaceContainerHighest, 0.9)
            topLeftRadius: first ? outer : inner
            bottomLeftRadius: first ? outer : inner
            topRightRadius: last ? outer : inner
            bottomRightRadius: last ? outer : inner

            Behavior on inner {
                SpringFast {}
            }

            Behavior on color {
                ColorEase {}
            }

            Row {
                id: content

                anchors.centerIn: parent
                spacing: 6

                Icon {
                    visible: (seg.modelData.icon ?? "") !== ""
                    name: seg.modelData.icon ?? ""
                    size: 20
                    fill: seg.selected ? 1 : 0
                    color: seg.selected ? Colours.fgSecondaryContainer : Colours.fgSurfaceVariant
                }

                Txt {
                    visible: (seg.modelData.label ?? "") !== ""
                    anchors.verticalCenter: parent.verticalCenter
                    text: seg.modelData.label ?? ""
                    role: "labelL"
                    color: seg.selected ? Colours.fgSecondaryContainer : Colours.fgSurfaceVariant
                }
            }

            StateLayer {
                topLeftRadius: seg.topLeftRadius
                topRightRadius: seg.topRightRadius
                bottomLeftRadius: seg.bottomLeftRadius
                bottomRightRadius: seg.bottomRightRadius
                onClicked: root.picked(seg.modelData.id)
            }
        }
    }
}
