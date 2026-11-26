//@ pragma UseQApplication
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.services
import "modules"
import "modules/background"
import "modules/bar"
import "modules/capture"
import "modules/common"
import "modules/dashboard"
import "modules/launcher"
import "modules/lock"
import "modules/notifications"
import "modules/osd"
import "modules/overview"
import "modules/quicksettings"
import "modules/session"
import "modules/settings"
import "modules/wallpaper"

ShellRoot {
    id: root

    settings.watchFiles: false

    Component.onCompleted: {
        Perf.lowEnd;
        Scheme.mode;
        NightLight.enabled;
        TermTheme.enabled;
        GtkTheme.enabled;
        Clip.watching;
    }

    Variants {
        model: Quickshell.screens

        Background {}
    }

    Variants {
        model: Quickshell.screens

        Bar {}
    }

    Popups {}
    Osd {}
    Lock {}
    Ipc {}

    Popout {
        name: "launcher"
        edge: "top"
        offset: 96
        open: Panels.launcher
        onDismissed: Panels.close()
        content: LauncherContent {
            seed: Panels.launcherSeed
            onDone: Panels.close()
        }
    }

    Popout {
        name: "quicksettings"
        keepAlive: true
        edge: "top-right"
        open: Panels.quicksettings
        onDismissed: Panels.close()
        content: QuickSettingsContent {}
    }

    Popout {
        name: "session"
        edge: "fill"
        exclusiveKeyboard: true
        open: Panels.session
        onOpenChanged: {
            if (open)
                Session.refreshUptime();
        }
        onDismissed: Panels.close()
        content: SessionContent {
            onDone: Panels.close()
        }
    }

    Popout {
        name: "wallpaper"
        edge: "bottom"
        open: Panels.wallpaper
        onDismissed: Panels.close()
        content: WallpaperContent {
            onDone: Panels.close()
        }
    }

    Popout {
        name: "overview"
        edge: "fill"
        exclusiveKeyboard: true
        open: Panels.overview
        onDismissed: Panels.close()
        content: OverviewContent {
            onDone: Panels.close()
        }
    }

    Popout {
        name: "dashboard"
        keepAlive: true
        edge: "top"
        open: Panels.dashboard
        onDismissed: Panels.close()
        content: DashboardContent {
            onDone: Panels.close()
        }
    }

    Popout {
        name: "capture"
        edge: "bottom"
        open: Panels.capture
        onDismissed: Panels.close()
        content: CaptureContent {
            onDone: Panels.close()
        }
    }

    LazyLoader {
        active: Panels.settings

        SettingsWindow {
            onFinished: Panels.settings = false
        }
    }
}
