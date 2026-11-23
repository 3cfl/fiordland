pragma ComponentBehavior: Bound

import "popouts" as BarPopouts
import "components"
import "components/workspaces"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.services

Item {
    id: root

    required property ShellScreen screen
    required property ScreenState screenState
    required property BarPopouts.Wrapper popouts
    required property bool fullscreen
    readonly property int hPadding: Tokens.padding.large
    readonly property bool clockOn: Config.bar.entries.values.some(e => e.id === "clock" && e.enabled)

    function closeTray(): void {
    }

    function overClock(x: real): bool {
        return clockOn && x >= clock.x - Tokens.padding.medium && x <= clock.x + clock.width + Tokens.padding.medium;
    }

    function checkPopout(x: real): void {
        const ch = row.childAt(x - row.x, row.height / 2) as EntryWrapper;

        if (!ch) {
            popouts.hasCurrent = false;
            return;
        }

        const id = ch.entryId;

        if (id === "statusIcons" && Config.bar.popouts.statusIcons) {
            const items = (ch.item as StatusIcons).items;
            const icon = items.childAt(mapToItem(items, x, 0).x, items.height / 2);
            if (icon) {
                popouts.currentName = icon.name;
                popouts.currentCenter = Qt.binding(() => icon.mapToItem(root, icon.implicitWidth / 2, 0).x);
                popouts.hasCurrent = true;
            }
        } else if (id === "tray" && Config.bar.popouts.tray) {
            const tray = ch.item as Tray;
            const trayItem = tray.layout.childAt(mapToItem(tray.layout, x, 0).x, tray.layout.height / 2);
            let index = -1;
            for (let i = 0; i < tray.items.count; i++)
                if (tray.items.itemAt(i) === trayItem)
                    index = i;
            if (index >= 0) {
                popouts.currentName = `traymenu${index}`;
                popouts.currentCenter = Qt.binding(() => trayItem.mapToItem(root, trayItem.implicitWidth / 2, 0).x);
                popouts.hasCurrent = true;
            } else {
                popouts.hasCurrent = false;
            }
        } else if (id === "activeWindow" && Config.bar.popouts.activeWindow && Config.bar.activeWindow.showOnHover) {
            popouts.currentName = "activewindow";
            popouts.currentCenter = (ch.item as Item).mapToItem(root, (ch.item as Item).implicitWidth / 2, 0).x;
            popouts.hasCurrent = true;
        } else {
            popouts.hasCurrent = false;
        }
    }

    function handleWheel(x: real, angleDelta: point): void {
        const ch = row.childAt(x - row.x, row.height / 2) as EntryWrapper;
        if (ch?.entryId === "workspaces" && Config.bar.scrollActions.workspaces) {
            const mon = Hypr.monitorFor(screen);
            const specialWs = mon?.lastIpcObject.specialWorkspace.name;
            if (specialWs?.length > 0)
                Hypr.dispatch(Hypr.usingLua ? `hl.dsp.workspace.toggle_special("${specialWs.slice(8)}")` : `togglespecialworkspace ${specialWs.slice(8)}`);
            else if (angleDelta.y < 0 || mon.activeWorkspace?.id > 1)
                Hypr.dispatch(Hypr.usingLua ? `hl.dsp.focus({ workspace = "r${angleDelta.y > 0 ? "-" : "+"}1" })` : `workspace r${angleDelta.y > 0 ? "-" : "+"}1`);
        } else if (x > width / 2 && Config.bar.scrollActions.volume) {
            if (angleDelta.y > 0)
                Audio.incrementVolume();
            else if (angleDelta.y < 0)
                Audio.decrementVolume();
        } else if (Config.bar.scrollActions.brightness) {
            const monitor = Brightness.getMonitorForScreen(screen);
            if (angleDelta.y > 0)
                monitor.setBrightness(monitor.brightness + GlobalConfig.services.brightnessIncrement);
            else if (angleDelta.y < 0)
                monitor.setBrightness(monitor.brightness - GlobalConfig.services.brightnessIncrement);
        }
    }

    RowLayout {
        id: row

        anchors.fill: parent
        anchors.leftMargin: root.hPadding
        anchors.rightMargin: root.hPadding
        spacing: Tokens.spacing.medium

        Repeater {
            id: repeater

            model: ScriptModel {
                values: root.Config.bar.entries.values.filter(e => e.enabled && e.id !== "clock")
            }

            DelegateChooser {
                role: "id"

                DelegateChoice {
                    roleValue: "spacer"
                    delegate: EntryWrapper {
                        Layout.fillWidth: true
                    }
                }
                DelegateChoice {
                    roleValue: "logo"
                    delegate: EntryWrapper {
                        OsIcon {
                            objectName: "taskbarLogo"
                        }
                    }
                }
                DelegateChoice {
                    roleValue: "workspaces"
                    delegate: EntryWrapper {
                        Workspaces {
                            objectName: "taskbarWorkspaces"
                            screen: root.screen
                            fullscreen: root.fullscreen
                        }
                    }
                }
                DelegateChoice {
                    roleValue: "activeWindow"
                    delegate: EntryWrapper {
                        ActiveWindow {
                            objectName: "taskbarActiveWindow"
                            bar: root
                            maxWidth: Math.max(0, root.width / 2 - root.hPadding - clock.width / 2 - x - Tokens.spacing.large * 2)
                        }
                    }
                }
                DelegateChoice {
                    roleValue: "tray"
                    delegate: EntryWrapper {
                        Tray {
                            objectName: "taskbarTray"
                        }
                    }
                }
                DelegateChoice {
                    roleValue: "statusIcons"
                    delegate: EntryWrapper {
                        StatusIcons {
                            objectName: "taskbarStatusIcons"
                        }
                    }
                }
                DelegateChoice {
                    roleValue: "power"
                    delegate: EntryWrapper {
                        Power {
                            objectName: "taskbarPowerButton"
                            screenState: root.screenState
                        }
                    }
                }
            }
        }
    }

    Clock {
        id: clock

        objectName: "taskbarClock"
        anchors.centerIn: parent
        visible: root.clockOn
        screenState: root.screenState
    }

    component EntryWrapper: Item {
        required property var modelData
        required property int index
        default property Item item
        readonly property string entryId: modelData.id

        Layout.alignment: Qt.AlignVCenter

        implicitWidth: item?.implicitWidth ?? 0
        implicitHeight: item?.implicitHeight ?? 0

        children: item
    }
}
