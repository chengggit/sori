import QtQuick
import QtQuick.Controls
import "../style"

AppButton {
    id: root
    property real rowStep: 32
    property Item coordinateItem: null
    readonly property bool dragging: pointer.pressed
    property real dragOffset: 0
    signal moveRequested(int offset)
    signal dragFinished()
    iconName: "grip-vertical"
    variant: "ghost"
    implicitWidth: 24
    implicitHeight: 24
    down: pointer.pressed
    Accessible.name: "Reorder dictionary"
    Accessible.description: "Drag up or down, or use the Up and Down arrow keys."
    ToolTip {
        id: reorderTooltip
        objectName: "dictionaryReorderTooltip"
        visible: pointer.containsMouse && !pointer.pressed
        delay: 500
        text: "Drag to reorder"
        padding: 8
        contentItem: AppText {
            text: reorderTooltip.text
            font.pixelSize: 12
            color: Theme.foreground
        }
        background: Rectangle {
            color: Theme.card
            border.color: Theme.border
            radius: Theme.radiusSmall
        }
    }
    Keys.onUpPressed: moveRequested(-1)
    Keys.onDownPressed: moveRequested(1)

    MouseArea {
        id: pointer
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        preventStealing: true
        property real startY: 0
        onPressed: mouse => {
            root.forceActiveFocus(Qt.MouseFocusReason)
            startY = mapToItem(root.coordinateItem, mouse.x, mouse.y).y
            root.dragOffset = 0
        }
        onPositionChanged: mouse => {
            if (pressed)
                root.dragOffset = mapToItem(root.coordinateItem, mouse.x, mouse.y).y - startY
        }
        onReleased: mouse => {
            const distance = mapToItem(root.coordinateItem, mouse.x, mouse.y).y - startY
            root.dragOffset = 0
            root.dragFinished()
            root.moveRequested(Math.round(distance / Math.max(1, root.rowStep)))
        }
        onCanceled: {
            root.dragOffset = 0
            root.dragFinished()
        }
    }
}
