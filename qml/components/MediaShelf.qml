pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../style"

ColumnLayout {
    id: shelf

    property string title: ""
    property var model: []
    property bool video: false
    property real cardsPerView: 5
    property real minimumCardWidth: 150
    property real maximumCardWidth: 240
    property real coverRatio: 0.75
    property bool showMeta: false
    property string emptyText: ""
    property string emptyActionText: ""

    signal openRequested(var item)
    signal editRequested(var item)
    signal removeRequested(var item)
    signal emptyActionRequested()

    readonly property int count: shelf.model ? shelf.model.length : 0
    readonly property real cardWidth: Math.round(Math.max(shelf.minimumCardWidth,
        Math.min(shelf.maximumCardWidth, shelf.width / shelf.cardsPerView)))
    readonly property real coverHeight: Math.round(shelf.cardWidth / shelf.coverRatio)
    readonly property int titleBlockHeight: 8 + 36
    readonly property int metaBlockHeight: shelf.showMeta ? 4 + 16 : 0
    readonly property real rowHeight: shelf.coverHeight + shelf.titleBlockHeight + shelf.metaBlockHeight
    readonly property bool hovered: hover.hovered

    spacing: 10

    HoverHandler {
        id: hover
    }

    function scroll(direction) {
        const minimum = list.originX;
        const maximum = Math.max(minimum, minimum + list.contentWidth - list.width);
        const step = Math.max(shelf.cardWidth + Theme.dashboardColumnGap,
            Math.round(viewport.width * 0.9));
        const destination = Math.max(minimum, Math.min(maximum, list.contentX + direction * step));
        if (Math.abs(destination - list.contentX) < 1)
            return;
        scrollAnimation.stop();
        scrollAnimation.from = list.contentX;
        scrollAnimation.to = destination;
        scrollAnimation.restart();
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        AppText {
            text: shelf.title
            font.pixelSize: 18
            font.weight: Font.DemiBold
        }
        AppText {
            text: shelf.count
            color: Theme.mutedForeground
            font.pixelSize: 14
            Layout.alignment: Qt.AlignBottom
            Layout.bottomMargin: 3
            visible: shelf.count > 0
        }
        Item {
            Layout.fillWidth: true
        }
    }

    Item {
        id: viewport
        Layout.fillWidth: true
        Layout.preferredHeight: shelf.rowHeight

        ListView {
            id: list
            anchors.fill: parent
            visible: shelf.count > 0
            orientation: ListView.Horizontal
            spacing: Theme.dashboardColumnGap
            model: shelf.model
            boundsBehavior: Flickable.StopAtBounds
            maximumFlickVelocity: 2400
            onMovementStarted: scrollAnimation.stop()
            onModelChanged: Qt.callLater(list.positionViewAtBeginning)
            onWidthChanged: if (list.contentX > list.originX + list.contentWidth - list.width)
                list.contentX = Math.max(list.originX, list.originX + list.contentWidth - list.width)

            NumberAnimation {
                id: scrollAnimation
                target: list
                property: "contentX"
                duration: 320
                easing.type: Easing.OutCubic
            }

            delegate: MediaCard {
                required property var modelData
                required property int index

                width: shelf.cardWidth
                height: shelf.rowHeight
                item: modelData
                video: shelf.video
                coverHeight: shelf.coverHeight
                showMeta: shelf.showMeta
                tintIndex: index

                onOpenRequested: shelf.openRequested(modelData)
                onEditRequested: shelf.editRequested(modelData)
                onRemoveRequested: shelf.removeRequested(modelData)
            }
        }

        Rectangle {
            visible: shelf.count === 0 && shelf.emptyText !== ""
            width: shelf.cardWidth
            height: shelf.rowHeight
            radius: Theme.radius
            color: "transparent"
            border.width: 1
            border.color: Theme.border

            ColumnLayout {
                anchors.centerIn: parent
                width: Math.min(parent.width - 24, 190)
                spacing: 8

                Icon {
                    Layout.alignment: Qt.AlignHCenter
                    name: shelf.video ? "film" : "file-text"
                    size: 22
                    color: Theme.mutedForeground
                }
                AppText {
                    Layout.fillWidth: true
                    text: shelf.emptyText
                    color: Theme.mutedForeground
                    font.pixelSize: 12
                    wrapMode: Text.Wrap
                    horizontalAlignment: Text.AlignHCenter
                }
                AppButton {
                    Layout.alignment: Qt.AlignHCenter
                    visible: shelf.emptyActionText !== ""
                    text: shelf.emptyActionText
                    iconName: "plus"
                    small: true
                    onClicked: shelf.emptyActionRequested()
                }
            }
        }

        Rectangle {
            id: leftArrow
            visible: shelf.hovered && !list.atXBeginning
            anchors.left: parent.left
            anchors.leftMargin: 6
            y: Math.round((shelf.coverHeight - height) / 2)
            width: 36
            height: 36
            radius: width / 2
            color: Theme.card
            border.width: 1
            border.color: Theme.border

            Icon {
                anchors.centerIn: parent
                name: "arrow-left"
                size: 16
                color: Theme.foreground
            }
            TapHandler {
                onTapped: shelf.scroll(-1)
            }
            HoverHandler {
                cursorShape: Qt.PointingHandCursor
            }
        }

        Rectangle {
            id: rightArrow
            visible: shelf.hovered && !list.atXEnd
            anchors.right: parent.right
            anchors.rightMargin: 6
            y: Math.round((shelf.coverHeight - height) / 2)
            width: 36
            height: 36
            radius: width / 2
            color: Theme.card
            border.width: 1
            border.color: Theme.border

            Icon {
                anchors.centerIn: parent
                name: "arrow-left"
                size: 16
                rotation: 180
                color: Theme.foreground
            }
            TapHandler {
                onTapped: shelf.scroll(1)
            }
            HoverHandler {
                cursorShape: Qt.PointingHandCursor
            }
        }
    }
}
