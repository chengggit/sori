import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../style"

RowLayout {
    id: root
    property bool hasText: false
    property bool showingText: false
    property bool canAttach: true
    property bool canRetry: false
    property string filename: ""
    signal addRequested()
    signal removeRequested()
    signal toggleRequested()
    signal retryRequested()
    spacing: Theme.controlGap

    ColumnLayout {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        spacing: 4
        AppText { text: "Transcript"; font.weight: Font.DemiBold }
        AppText {
            Layout.fillWidth: true
            visible: root.showingText && root.filename !== ""
            text: root.filename
            color: Theme.mutedForeground
            font.pixelSize: 12
            elide: Text.ElideRight
        }
    }
    AppButton {
        visible: root.canRetry
        text: "Retry subtitles"
        variant: "ghost"
        small: true
        onClicked: root.retryRequested()
    }
    AppButton {
        visible: root.hasText
        text: root.showingText ? "Show subtitles" : "Show text"
        variant: "ghost"
        small: true
        onClicked: root.toggleRequested()
    }
    AppButton {
        objectName: "addTranscriptButton"
        visible: !root.hasText
        enabled: root.canAttach
        text: "Add transcript"
        iconName: "plus"
        variant: "outline"
        small: true
        onClicked: root.addRequested()
    }
    AppButton {
        id: moreButton
        objectName: "transcriptMoreButton"
        visible: root.hasText
        iconName: "ellipsis-vertical"
        variant: "ghost"
        Accessible.name: "Transcript options"
        onClicked: options.open()
        Menu {
            id: options
            objectName: "transcriptOptions"
            y: moreButton.height
            x: moreButton.width - width
            background: Rectangle { color: Theme.card; radius: Theme.radius; border.color: Theme.border }
            MenuItem {
                objectName: "replaceTranscriptAction"
                text: "Replace transcript (.txt)"
                enabled: root.canAttach
                onTriggered: root.addRequested()
            }
            MenuItem {
                objectName: "removeTranscriptAction"
                text: "Remove transcript"
                onTriggered: root.removeRequested()
            }
        }
    }
    onVisibleChanged: if (!visible) options.close()
}
