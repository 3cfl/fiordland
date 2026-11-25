pragma ComponentBehavior: Bound

import QtQuick
import qs.theme

SpringAnimation {
    spring: Motion.fastSpring
    damping: Motion.fastDamping
    epsilon: 0.01
}
