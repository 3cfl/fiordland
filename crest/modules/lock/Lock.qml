pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.theme

Scope {
    id: root

    Auth {
        id: authCtx

        active: Session.locked
    }

    IdleMonitor {
        enabled: !Config.demo && Config.lock.idleMinutes > 0 && !Session.locked
        timeout: Math.max(1, Config.lock.idleMinutes) * 60
        respectInhibitors: true
        onIsIdleChanged: {
            if (isIdle)
                Session.lock();
        }
    }

    WlSessionLock {
        id: lock

        locked: Session.locked

        WlSessionLockSurface {
            color: Colours.surfaceContainerLowest

            LockContent {
                anchors.fill: parent
                auth: authCtx
                onFinished: Session.locked = false
            }
        }
    }
}
