pragma ComponentBehavior: Bound

import QtQuick
import qs.components
import qs.theme

Glass {
    id: root

    property bool live: true

    implicitWidth: 420
    implicitHeight: card.implicitHeight + 48
    radius: Style.rXl

    Behavior on implicitHeight {
        SpringDefault {}
    }

    PairCard {
        id: card

        x: 24
        y: 24
        width: parent.width - 48
        focus: true
    }
}
