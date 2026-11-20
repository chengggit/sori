pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes
import sori_core
import "../style"

ItemDelegate {
    id: card

    property var item: ({})
    property bool video: false
    property real coverHeight: 0
    property bool showMeta: false
    property int tintIndex: 0

    signal openRequested()
    signal editRequested()
    signal removeRequested()

    readonly property string title: card.video
        ? (card.item.displayTitle || card.item.title || "Untitled video")
        : (card.item.title || "Untitled text")
    readonly property string artwork: card.item.thumbnailUrl ?? ""
    readonly property real duration: card.video ? (card.item.duration ?? 0) : 0
    readonly property real seconds: card.video ? (card.item.seconds ?? 0) : 0
    readonly property real progress: card.duration > 0
        ? Math.min(1, Math.max(0, card.seconds / card.duration)) : 0
    readonly property string meta: {
        if (!card.video)
            return "";
        if (card.duration > 0)
            return (card.seconds > 0 ? Player.formatTime(card.seconds) + " / " : "") + Player.formatTime(card.duration);
        return card.seconds > 0 ? Player.formatTime(card.seconds) + " watched" : "Not started";
    }
    readonly property color cornerFill: card.visualFocus ? Theme.hero : Theme.background
    readonly property color coverColor: card.tintIndex % 3 === 0 ? Theme.hero
        : card.tintIndex % 3 === 1 ? Theme.accentSoft : Theme.chip
    readonly property string watermark: card.title.trim().substring(0, 1)
    readonly property bool revealed: card.hovered || card.visualFocus || actions.opened

    padding: 0
    hoverEnabled: true
    Accessible.name: card.title
    implicitWidth: 220
    implicitHeight: card.coverHeight + 8 + 36 + (card.showMeta ? 20 : 0)

    onClicked: card.openRequested()

    HoverHandler {
        cursorShape: Qt.PointingHandCursor
    }

    component ShapeCorner: Shape {
        id: cornerShape

        property color fill: Theme.background

        width: Theme.radius
        height: width
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: 0
            fillColor: cornerShape.fill
            PathSvg { path: "M 0 0 H %1 A %1 %1 0 0 0 0 %1 Z".arg(Theme.radius) }
        }
    }

    background: Rectangle {
        radius: Theme.radiusSmall
        color: card.visualFocus ? Theme.hero : "transparent"
    }

    contentItem: ColumnLayout {
        spacing: 0

        Item {
            id: cover
            Layout.fillWidth: true
            Layout.preferredHeight: card.coverHeight
            clip: true

            Rectangle {
                anchors.fill: parent
                radius: Theme.radius
                color: card.video ? Theme.chip : card.coverColor
            }

            Image {
                anchors.fill: parent
                asynchronous: true
                cache: false
                fillMode: Image.PreserveAspectCrop
                visible: card.video && status === Image.Ready
                source: card.video ? card.artwork : ""
                scale: card.revealed ? 1.02 : 1

                Behavior on scale {
                    NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                }
            }

            Icon {
                anchors.centerIn: parent
                visible: card.video && card.artwork === ""
                name: "film"
                size: 28
                color: Theme.mutedForeground
            }

            AppText {
                visible: !card.video
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.rightMargin: 14
                anchors.bottomMargin: -6
                text: card.watermark
                korean: true
                font.pixelSize: Math.round(card.coverHeight * 0.62)
                font.weight: Font.DemiBold
                color: Qt.alpha(Theme.dashboardAccent, 0.22)
            }

            Rectangle {
                visible: !card.video
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.margins: 12
                width: badge.implicitWidth + 14
                height: 20
                radius: height / 2
                color: Theme.card

                AppText {
                    id: badge
                    anchors.centerIn: parent
                    text: "TEXT"
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                    font.letterSpacing: 0.8
                    color: Theme.dashboardAccent
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: Theme.radius
                color: Qt.alpha("#000000", 0.22)
                opacity: card.revealed ? 1 : 0

                Behavior on opacity {
                    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                }
            }

            Rectangle {
                anchors.centerIn: parent
                width: 44
                height: width
                radius: width / 2
                color: Theme.card
                opacity: card.revealed ? 1 : 0
                scale: card.revealed ? 1 : 0.9

                Behavior on opacity {
                    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                }

                Behavior on scale {
                    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                }

                Icon {
                    anchors.centerIn: parent
                    name: card.video ? "play-filled" : "book-open"
                    size: 20
                    color: Theme.dashboardAccent
                }
            }

            Rectangle {
                visible: card.video
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 4
                color: Qt.alpha("#000000", 0.35)

                Rectangle {
                    width: parent.width * card.progress
                    height: parent.height
                    color: Theme.dashboardProgress
                }
            }

            AppButton {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: 8
                width: 28
                height: 28
                iconName: "ellipsis-vertical"
                iconSize: 14
                variant: "outline"
                visible: card.revealed
                Accessible.name: "Card actions"
                onClicked: actions.open()
            }

            // Round only the artwork by painting the card surface over each
            // corner. Anchors are used instead of parent-size bindings because
            // item parents are cleared while delegates are torn down.
            ShapeCorner {
                anchors.top: parent.top
                anchors.left: parent.left
                fill: card.cornerFill
            }
            ShapeCorner {
                anchors.top: parent.top
                anchors.right: parent.right
                rotation: 90
                fill: card.cornerFill
            }
            ShapeCorner {
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                rotation: 180
                fill: card.cornerFill
            }
            ShapeCorner {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                rotation: 270
                fill: card.cornerFill
            }
        }

        AppText {
            id: titleText
            Layout.fillWidth: true
            Layout.topMargin: 8
            // Reserve only the lines the title actually needs so the metadata
            // below sits directly under it. Baselines are fixed at 18px.
            Layout.preferredHeight: Math.max(18, Math.min(36, titleText.implicitHeight))
            text: card.title
            font.pixelSize: 13
            font.weight: Font.DemiBold
            lineHeightMode: Text.FixedHeight
            lineHeight: 18
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
            verticalAlignment: Text.AlignTop
        }

        AppText {
            Layout.fillWidth: true
            Layout.topMargin: 4
            Layout.preferredHeight: 16
            visible: card.showMeta
            text: card.meta
            color: Theme.mutedForeground
            font.pixelSize: 12
            elide: Text.ElideRight
        }
    }

    Menu {
        id: actions

        x: Math.round(card.width - width - 8)
        y: 8
        width: 168
        padding: 6
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        background: Rectangle {
            radius: Theme.radius
            color: Theme.card
            border.width: 1
            border.color: Theme.border
        }

        MenuItem {
            id: openItem
            height: 34
            width: actions.availableWidth
            onTriggered: card.openRequested()

            contentItem: AppText {
                text: card.video ? "Watch" : "Read"
                leftPadding: 10
                rightPadding: 10
                verticalAlignment: Text.AlignVCenter
                font.pixelSize: 13
            }

            background: Rectangle {
                radius: Theme.radiusSmall
                color: openItem.hovered ? Theme.neutralHover : "transparent"
            }
        }

        MenuItem {
            id: editItem
            // Menu layouts keep a slot for invisible items, so collapse it too.
            visible: !card.video
            height: visible ? 34 : 0
            width: actions.availableWidth
            onTriggered: card.editRequested()

            contentItem: AppText {
                text: "Edit"
                leftPadding: 10
                rightPadding: 10
                verticalAlignment: Text.AlignVCenter
                font.pixelSize: 13
            }

            background: Rectangle {
                radius: Theme.radiusSmall
                color: editItem.hovered ? Theme.neutralHover : "transparent"
            }
        }

        MenuItem {
            id: removeItem
            height: 34
            width: actions.availableWidth
            onTriggered: card.removeRequested()

            contentItem: AppText {
                text: card.video ? "Remove" : "Delete"
                leftPadding: 10
                rightPadding: 10
                verticalAlignment: Text.AlignVCenter
                font.pixelSize: 13
                color: Theme.destructive
            }

            background: Rectangle {
                radius: Theme.radiusSmall
                color: removeItem.hovered ? Theme.neutralHover : "transparent"
            }
        }
    }
}
