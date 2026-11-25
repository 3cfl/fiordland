pragma ComponentBehavior: Bound

import QtQuick
import qs.theme

SpringAnimation {
    spring: Motion.slowSpring
    damping: Motion.slowDamping
    epsilon: 0.01
}
