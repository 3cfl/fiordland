pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import qs.theme

Shape {
    id: root

    property string shape: "cookie9"
    property color color: Colours.primary
    property int segments: 180
    readonly property var presets: ({
            circle: [1, 0, 1],
            cookie4: [4, 0.14, 1],
            cookie6: [6, 0.11, 1],
            cookie9: [9, 0.08, 1],
            cookie12: [12, 0.06, 1],
            clover4: [4, 0.32, 0.45],
            clover8: [8, 0.2, 0.5],
            sunny: [8, 0.1, 1.7],
            softburst: [10, 0.15, 1.4],
            flower: [8, 0.18, 0.65],
            puffy: [6, 0.18, 0.55]
        })
    readonly property var target: presets[shape] ?? presets.circle
    property var from: target
    property var to: target
    property real progress: 1
    readonly property var points: {
        const n = segments;
        const a = from;
        const b = to;
        const t = progress;
        const cx = width / 2;
        const cy = height / 2;
        const pts = [];
        for (let i = 0; i <= n; i++) {
            const th = (i / n) * Math.PI * 2 - Math.PI / 2;
            const ra = 1 - a[1] + a[1] * Math.pow((1 + Math.cos(a[0] * th)) / 2, a[2]);
            const rb = 1 - b[1] + b[1] * Math.pow((1 + Math.cos(b[0] * th)) / 2, b[2]);
            const r = ra + (rb - ra) * t;
            pts.push(Qt.point(cx + Math.cos(th) * r * cx, cy + Math.sin(th) * r * cy));
        }
        return pts;
    }

    onTargetChanged: {
        from = to;
        to = target;
        progress = 0;
        morph.restart();
    }

    preferredRendererType: Shape.CurveRenderer

    SpringAnimation {
        id: morph

        target: root
        property: "progress"
        to: 1
        spring: Motion.fastSpring
        damping: Motion.defaultDamping
        epsilon: 0.005
    }

    ShapePath {
        fillColor: root.color
        strokeWidth: -1
        strokeColor: "transparent"

        PathPolyline {
            path: root.points
        }
    }
}
