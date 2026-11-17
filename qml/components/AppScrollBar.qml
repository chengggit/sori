import QtQuick
import QtQuick.Controls
import "../style"

ScrollBar {
    id: root

    readonly property bool inUse: active || hovered || pressed

    padding: 2
    hoverEnabled: true
    minimumSize: Math.min(1, 24 / Math.max(1, orientation === Qt.Vertical ? availableHeight : availableWidth))
    background: null

    onInUseChanged: {
        if (inUse)
            linger.stop()
        else
            linger.restart()
    }

    Timer {
        id: linger
        interval: Theme.scrollBarHideDelay
    }

    contentItem: Rectangle {
        implicitWidth: Theme.scrollBarThickness
        implicitHeight: Theme.scrollBarThickness
        radius: Theme.scrollBarThickness / 2
        color: Theme.scrollBarColor
        opacity: root.size >= 1 || !(root.inUse || linger.running) ? 0
            : root.hovered || root.pressed ? Theme.scrollBarActiveOpacity : Theme.scrollBarOpacity

        Behavior on opacity {
            NumberAnimation { duration: 120 }
        }
    }
}
