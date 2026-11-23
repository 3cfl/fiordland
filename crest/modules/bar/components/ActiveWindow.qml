pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services
import qs.utils

Item {
    id: root

    required property var bar
    property real maxWidth: 320
    property color colour: Colours.palette.m3onSurfaceVariant

    readonly property string windowTitle: {
        const title = Hypr.activeToplevel?.title;
        if (!title)
            return Tr.trCtx("Desktop", "shown when no window is focused");
        if (Config.bar.activeWindow.compact) {
            const parts = title.split(/\s+[\-–—]\s+/);
            if (parts.length > 1)
                return parts[parts.length - 1].trim();
        }
        return title;
    }

    clip: true
    implicitWidth: Math.min(maxWidth, icon.implicitWidth + Tokens.spacing.small + title.implicitWidth)
    implicitHeight: Math.max(icon.implicitHeight, title.implicitHeight)

    Behavior on implicitWidth {
        Anim {}
    }

    Loader {
        asynchronous: true
        anchors.fill: parent
        active: !Config.bar.activeWindow.showOnHover

        sourceComponent: MouseArea {
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                const popouts = root.bar.popouts;
                if (popouts.hasCurrent) {
                    popouts.hasCurrent = false;
                } else {
                    popouts.currentName = "activewindow";
                    popouts.currentCenter = root.mapToItem(root.bar, root.implicitWidth / 2, 0).x;
                    popouts.hasCurrent = true;
                }
            }
        }
    }

    MaterialIcon {
        id: icon

        anchors.verticalCenter: parent.verticalCenter
        animate: true
        text: Icons.getAppCategoryIcon(Hypr.activeToplevel?.lastIpcObject.class, "desktop_windows")
        color: Colours.palette.m3primary
    }

    StyledText {
        id: title

        anchors.left: icon.right
        anchors.leftMargin: Tokens.spacing.small
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        animate: true
        text: root.windowTitle
        font: Tokens.font.body.small
        color: root.colour
        elide: Text.ElideRight
    }
}
