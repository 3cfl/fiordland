import QtQuick

QtObject {
    id: root

    property bool active: false
    property bool held: false

    signal acquire
    signal release

    function sync(): void {
        if (active && !held) {
            held = true;
            acquire();
        } else if (!active && held) {
            held = false;
            release();
        }
    }

    onActiveChanged: sync()
    Component.onCompleted: sync()
    Component.onDestruction: if (held)
        release()
}
