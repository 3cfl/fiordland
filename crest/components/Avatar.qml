pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import qs.theme

Item {
    id: root

    property string source
    property string shape: "cookie9"
    property string initial
    readonly property bool hasImage: img.status === Image.Ready

    implicitWidth: 96
    implicitHeight: 96

    ExprShape {
        id: base

        anchors.fill: parent
        shape: root.shape
        color: Colours.primaryContainer
        visible: !root.hasImage
    }

    Txt {
        anchors.centerIn: parent
        visible: !root.hasImage && root.initial !== ""
        text: root.initial.charAt(0).toUpperCase()
        role: "displayS"
        font.pixelSize: root.height * 0.42
        font.weight: 600
        color: Colours.fgPrimaryContainer
    }

    Icon {
        anchors.centerIn: parent
        visible: !root.hasImage && root.initial === ""
        name: "person"
        fill: 1
        size: root.height * 0.5
        color: Colours.fgPrimaryContainer
    }

    Image {
        id: img

        anchors.fill: parent
        source: root.source
        sourceSize.width: width * 2
        sourceSize.height: height * 2
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        visible: false
    }

    ExprShape {
        id: mask

        anchors.fill: parent
        shape: root.shape
        color: "white"
        visible: false
        layer.enabled: root.hasImage && Style.effects
        layer.samples: 4
    }

    MultiEffect {
        anchors.fill: parent
        visible: root.hasImage && Style.effects
        source: img
        maskEnabled: true
        maskSource: mask
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1
    }

    Canvas {
        id: canvas

        anchors.fill: parent
        visible: root.hasImage && !Style.effects
        renderStrategy: Canvas.Cooperative
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const pts = base.points;
            if (pts.length < 3)
                return;
            ctx.save();
            ctx.beginPath();
            ctx.moveTo(pts[0].x, pts[0].y);
            for (let i = 1; i < pts.length; i++)
                ctx.lineTo(pts[i].x, pts[i].y);
            ctx.closePath();
            ctx.clip();
            ctx.drawImage(img, 0, 0, width, height);
            ctx.restore();
        }

        Connections {
            target: base

            function onPointsChanged(): void {
                if (canvas.visible)
                    canvas.requestPaint();
            }
        }

        onVisibleChanged: {
            if (visible)
                requestPaint();
        }
    }
}
