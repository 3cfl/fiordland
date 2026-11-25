import QtQuick
import QtQuick.Effects
import qs.theme

Item {
    id: root

    property real radius: Style.rXl
    property color tint: Colours.surfaceContainer
    property real alpha: Style.glassAlpha
    property bool shadow: true
    property real shadowBlur: 32
    property real shadowOffset: 12
    property real shadowStrength: 0.35
    property bool highlight: true
    property real topLeftRadius: radius
    property real topRightRadius: radius
    property real bottomLeftRadius: radius
    property real bottomRightRadius: radius
    default property alias content: body.data

    RectangularShadow {
        anchors.fill: fill
        visible: root.shadow && Style.shadows && root.width > 0
        radius: Math.min(root.radius, height / 2)
        offset.y: root.shadowOffset
        blur: root.shadowBlur
        color: Qt.rgba(0, 0, 0, root.shadowStrength)
        cached: true
    }

    Rectangle {
        id: fill

        anchors.fill: parent
        topLeftRadius: root.topLeftRadius
        topRightRadius: root.topRightRadius
        bottomLeftRadius: root.bottomLeftRadius
        bottomRightRadius: root.bottomRightRadius
        color: Colours.alpha(root.tint, root.alpha)
    }

    Item {
        visible: root.highlight
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: Math.max(2, Math.min(root.topLeftRadius, root.height / 2))
        clip: true

        Rectangle {
            width: parent.width
            height: root.height
            topLeftRadius: root.topLeftRadius
            topRightRadius: root.topRightRadius
            bottomLeftRadius: root.bottomLeftRadius
            bottomRightRadius: root.bottomRightRadius
            color: "transparent"
            border.width: 1
            border.color: Colours.alpha(Colours.onSurface, Colours.light ? 0.5 : 0.1)
        }
    }

    Item {
        id: body

        anchors.fill: parent
    }
}
