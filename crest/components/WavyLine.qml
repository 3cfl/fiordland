import QtQuick
import QtQuick.Shapes
import qs.theme

Item {
    id: root

    property real value: 0
    property bool animating: true
    property color color: Colours.primary
    property color trackColor: Colours.secondaryContainer
    property real amplitude: 3
    property real wavelength: 28
    property real thickness: 4
    property real phase: 0
    readonly property real split: Math.max(0, Math.min(1, value)) * width
    readonly property var wave: {
        const pts = [];
        const end = Math.max(0, split - 4);
        const cy = height / 2;
        for (let x = 0; x <= end; x += 2)
            pts.push(Qt.point(x, cy + Math.sin((x / wavelength) * Math.PI * 2 - phase) * amplitude));
        if (pts.length === 0)
            pts.push(Qt.point(0, cy));
        return pts;
    }

    implicitHeight: 16

    FrameAnimation {
        running: root.animating && root.visible && !Motion.reduced
        onTriggered: root.phase = (root.phase + frameTime * 5) % (Math.PI * 2)
    }

    Rectangle {
        x: root.split + 6
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(0, root.width - x)
        height: root.thickness
        radius: height / 2
        color: root.trackColor
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: root.color
            strokeWidth: root.thickness
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            fillColor: "transparent"

            PathPolyline {
                path: root.wave
            }
        }
    }
}
