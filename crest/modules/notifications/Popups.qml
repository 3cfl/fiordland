pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import qs.components
import qs.services
import qs.theme

Scope {
    id: root

    LazyLoader {
        active: Notifs.popups.length > 0 && !Panels.notifications

        PanelWindow {
            screen: Panels.screen
            color: "transparent"
            WlrLayershell.namespace: "crest-notifications"
            WlrLayershell.layer: WlrLayer.Overlay
            exclusionMode: ExclusionMode.Normal
            anchors.top: true
            anchors.right: true
            implicitWidth: 420 + 40
            implicitHeight: Math.max(1, stack.implicitHeight + 48)

            mask: Region {
                item: stack
            }

            PopupStack {
                id: stack

                x: 28
                y: 8
                width: 420
            }
        }
    }

    component PopupStack: Column {
        spacing: 10

        Repeater {
            model: Notifs.popups.slice(0, 4)

            Item {
                id: slot

                required property var modelData
                property real enter: 0

                width: parent.width
                height: card.implicitHeight
                opacity: Math.min(1, enter * 1.5)

                Component.onCompleted: enter = 1

                Behavior on enter {
                    SpringDefault {}
                }

                NotifCard {
                    id: card

                    width: parent.width
                    entry: slot.modelData
                    x: (1 - slot.enter) * (parent.width + 24)
                }

                Timer {
                    interval: slot.modelData.timeout
                    running: slot.modelData.urgency !== NotificationUrgency.Critical && !card.hovered
                    onTriggered: Notifs.hidePopup(slot.modelData)
                }
            }
        }
    }
}
