pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import qs.theme

Item {
    id: root

    property var values: []
    property int capacity: 60
    property color color: Colours.primary
    property real thickness: 2.5
    property bool filled: true
    readonly property var line: {
        const pts = [];
        const n = values.length;
        if (n === 0 || width <= 0)
            return [Qt.point(0, height), Qt.point(width, height)];
        const step = width / Math.max(1, capacity - 1);
        const x0 = width - (n - 1) * step;
        for (let i = 0; i < n; i++) {
            const v = Math.max(0, Math.min(1, values[i]));
            pts.push(Qt.point(x0 + i * step, thickness + (height - thickness * 2) * (1 - v)));
        }
        if (n === 1)
            pts.unshift(Qt.point(x0 - step, pts[0].y));
        return pts;
    }
    readonly property var area: line.length > 0 ? line.concat([Qt.point(line[line.length - 1].x, height), Qt.point(line[0].x, height)]) : []

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: "transparent"
            strokeWidth: -1
            fillGradient: LinearGradient {
                x1: 0
                y1: 0
                x2: 0
                y2: root.height
                GradientStop {
                    position: 0
                    color: Colours.alpha(root.color, root.filled ? 0.28 : 0)
                }
                GradientStop {
                    position: 1
                    color: Colours.alpha(root.color, 0)
                }
            }

            PathPolyline {
                path: root.area
            }
        }

        ShapePath {
            strokeColor: root.color
            strokeWidth: root.thickness
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            fillColor: "transparent"

            PathPolyline {
                path: root.line
            }
        }
    }
}
