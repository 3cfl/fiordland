pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import qs.theme

Item {
    id: root

    property real value: 0
    property color color: Colours.primary
    property color trackColor: Colours.secondaryContainer
    property real thickness: 6
    property real amplitude: 2.2
    property int waves: 10
    property bool animating: true
    property real phase: 0
    property real shown: Math.max(0, Math.min(1, value))
    readonly property real gap: 0.035
    readonly property real cx: width / 2
    readonly property real cy: height / 2
    readonly property real r: Math.min(width, height) / 2 - thickness / 2 - amplitude
    readonly property var active: {
        const pts = [];
        const end = Math.max(0, shown - (shown < 1 ? gap / 2 : 0));
        const steps = Math.max(2, Math.round(end * 160));
        for (let i = 0; i <= steps; i++) {
            const t = (i / steps) * end;
            const th = t * Math.PI * 2 - Math.PI / 2;
            const rr = r + Math.sin(t * Math.PI * 2 * waves - phase) * amplitude * Math.min(1, end * 8);
            pts.push(Qt.point(cx + Math.cos(th) * rr, cy + Math.sin(th) * rr));
        }
        return pts;
    }
    readonly property var track: {
        const pts = [];
        const from = shown + gap;
        const to = 1 - gap;
        if (to <= from)
            return [];
        const steps = Math.max(2, Math.round((to - from) * 120));
        for (let i = 0; i <= steps; i++) {
            const th = (from + (i / steps) * (to - from)) * Math.PI * 2 - Math.PI / 2;
            pts.push(Qt.point(cx + Math.cos(th) * r, cy + Math.sin(th) * r));
        }
        return pts;
    }

    implicitWidth: 96
    implicitHeight: 96

    Behavior on shown {
        SpringDefault {}
    }

    FrameAnimation {
        running: root.animating && root.visible && !Motion.reduced
        onTriggered: root.phase = (root.phase + frameTime * 2.4) % (Math.PI * 2)
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: root.shown >= 1 - root.gap ? "transparent" : root.trackColor
            strokeWidth: root.thickness
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            fillColor: "transparent"

            PathPolyline {
                path: root.track
            }
        }

        ShapePath {
            strokeColor: root.shown > 0.002 ? root.color : "transparent"
            strokeWidth: root.thickness
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            fillColor: "transparent"

            PathPolyline {
                path: root.active
            }
        }
    }
}
