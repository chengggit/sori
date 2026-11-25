import QtQuick
import QtQuick.Effects
import "../style"

Item {
    id: root
    default property alias content: surface.data
    required property var dragHandle
    property var dragState: null
    property int rowIndex: 0
    readonly property real rowStep: dragHandle.rowStep
    readonly property bool dragging: dragHandle.dragging
    property real previewOffset: {
        if (!dragState || dragState.from < 0 || rowIndex === dragState.from)
            return 0
        if (dragState.from < rowIndex && rowIndex <= dragState.to)
            return -rowStep
        if (dragState.to <= rowIndex && rowIndex < dragState.from)
            return rowStep
        return 0
    }
    Behavior on previewOffset { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
    onDraggingChanged: {
        if (!dragState) return
        if (dragging) {
            dragState.to = rowIndex
            dragState.from = rowIndex
        } else {
            dragState.from = -1
            dragState.to = -1
        }
    }
    property Connections dragConnection: Connections {
        target: root.dragHandle
        function onDragFinished() {
            if (root.dragState) {
                root.dragState.from = -1
                root.dragState.to = -1
            }
        }
        function onDragOffsetChanged() {
            if (root.dragging && root.dragState) {
                root.dragState.to = Math.max(0, Math.min(root.dragState.count - 1,
                    root.rowIndex + Math.round(root.dragHandle.dragOffset / Math.max(1, root.rowStep))))
            }
        }
    }
    implicitHeight: 32
    z: dragging ? 100 : 0

    property Item placeholder: Rectangle {
        parent: root
        anchors.fill: parent
        visible: root.dragging
        color: Theme.neutralHover
        radius: Theme.radiusSmall
        border.color: Theme.border
        transform: Translate {
            y: root.dragState && root.dragState.from >= 0
                ? (root.dragState.to - root.dragState.from) * root.rowStep : 0
        }
    }

    property Item surface: Rectangle {
        id: surface
        objectName: "dictionaryDragSurface"
        parent: root
        anchors.fill: parent
        color: root.dragging ? Theme.card : "transparent"
        radius: Theme.radiusSmall
        border.width: root.dragging ? 1 : 0
        border.color: Theme.border
        scale: root.dragging ? 1.02 : 1
        transform: Translate { y: root.dragHandle.dragOffset + root.previewOffset }
        Behavior on scale { NumberAnimation { duration: 100 } }
        layer.enabled: root.dragging
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "#000000"
            shadowOpacity: 0.22
            shadowBlur: 0.6
            shadowVerticalOffset: 5
        }
    }
}
