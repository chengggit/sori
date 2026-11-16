import QtQuick
import QtQuick.Layouts
import "../Theme.js" as Theme
import "../components"

Item {
    id: root

    property int documentId: 0

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: 28
            spacing: 18

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Theme.radiusLarge
                color: Theme.card
                border.width: 1
                border.color: Theme.border

                EmptyState {
                    anchors.fill: parent
                    iconName: "book-open"
                    title: root.documentId > 0 ? "Document view is ready to connect" : "Choose a document"
                    message: root.documentId > 0
                        ? "The reading surface and progress controls are laid out. Document loading and Kiwi tokenization come in the next frontend steps."
                        : "Open a Korean text from My Library to start reading."
                }
            }

            Rectangle {
                Layout.preferredWidth: 330
                Layout.fillHeight: true
                radius: Theme.radiusLarge
                color: Theme.card
                border.width: 1
                border.color: Theme.border

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 12
                    AppText { text: "Word analysis"; font.pixelSize: 16; font.weight: Font.DemiBold }
                    AppText {
                        text: "Select a Korean word to see its morphology, meaning, and source context."
                        color: Theme.mutedForeground
                        font.pixelSize: 13
                        wrapMode: Text.Wrap
                        Layout.fillWidth: true
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        color: Theme.border
                    }
                    AppText {
                        text: "No word selected"
                        color: Theme.mutedForeground
                        font.pixelSize: 13
                    }
                    Item { Layout.fillHeight: true }
                    AppButton { text: "Save word"; iconName: "bookmark"; Layout.fillWidth: true; enabled: false }
                }
            }
        }
    }
}
