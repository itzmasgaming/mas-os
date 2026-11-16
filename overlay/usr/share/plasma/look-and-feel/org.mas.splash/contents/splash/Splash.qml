import QtQuick

// MAS loading screen (shown by Plasma right after login)
Rectangle {
    id: root
    color: "#050a14"
    property int stage: 0   // set by the Plasma splash engine, goes 1..6

    onStageChanged: bar.target = Math.min(1, stage / 6)

    gradient: Gradient {
        GradientStop { position: 0.0; color: "#050810" }
        GradientStop { position: 1.0; color: "#0d1730" }
    }

    // everything fades in
    Item {
        id: content
        anchors.fill: parent
        opacity: 0
        NumberAnimation on opacity { from: 0; to: 1; duration: 700; easing.type: Easing.OutCubic; running: true }

        readonly property real s: Math.max(0.5, Math.min(1.4, root.height / 1080))

        // glow behind the logo
        Image {
            id: glow
            source: "images/glow.png"
            width: 900 * content.s; height: width
            anchors.centerIn: logo
            smooth: true
            SequentialAnimation on opacity {
                loops: Animation.Infinite
                NumberAnimation { from: 0.45; to: 0.95; duration: 1800; easing.type: Easing.InOutSine }
                NumberAnimation { from: 0.95; to: 0.45; duration: 1800; easing.type: Easing.InOutSine }
            }
        }

        // spinning ring
        Image {
            source: "images/ring.png"
            width: 560 * content.s; height: width
            anchors.centerIn: logo
            smooth: true
            opacity: 0.9
            RotationAnimator on rotation { from: 0; to: 360; duration: 2400; loops: Animation.Infinite }
        }

        // your logo
        Image {
            id: logo
            source: "images/logo.png"
            fillMode: Image.PreserveAspectFit
            height: 380 * content.s
            width: height * sourceSize.width / sourceSize.height
            x: (parent.width - width) / 2
            y: parent.height * 0.46 - height / 2
            smooth: true
            SequentialAnimation on scale {
                loops: Animation.Infinite
                NumberAnimation { from: 1.0; to: 1.035; duration: 1800; easing.type: Easing.InOutSine }
                NumberAnimation { from: 1.035; to: 1.0; duration: 1800; easing.type: Easing.InOutSine }
            }
        }

        // progress bar
        Item {
            id: bar
            property real target: 0
            property real shown: 0
            width: 360 * content.s; height: 6 * content.s
            x: (parent.width - width) / 2
            y: logo.y + logo.height + 70 * content.s

            Image { anchors.fill: parent; source: "images/bar_track.png" }
            Item {
                height: parent.height
                width: Math.max(parent.height, parent.width * bar.shown)
                clip: true
                Image { width: bar.width; height: parent.height; source: "images/bar_fill.png" }
            }
            Behavior on shown { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
            onTargetChanged: shown = target
            // slow creep so it never looks stuck
            Timer {
                interval: 400; running: true; repeat: true
                onTriggered: if (bar.shown < 0.92) bar.shown = bar.shown + (0.92 - bar.shown) * 0.02
            }
        }
    }
}
