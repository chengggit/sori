import QtQuick
import QtQuick.Layouts
import "../style"
import "../components"

Item {
    id: root

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 28
        spacing: 20

        AppText { text: "Explore"; font.pixelSize: 26; font.weight: Font.DemiBold }
        AppText {
            text: "Find Korean videos and articles by topic."
            color: Theme.mutedForeground
            font.pixelSize: 13
        }
        AppInput {
            Layout.fillWidth: true
            Layout.maximumWidth: 640
            placeholderText: "Search YouTube for Korean videos"
            iconName: "search"
        }
        Flow {
            Layout.fillWidth: true
            spacing: 8
            Repeater {
                model: ["Daily life", "Vlogs", "Food", "Travel", "Culture", "Grammar"]
                delegate: AppButton {
                    required property string modelData
                    text: modelData
                    variant: "outline"
                    small: true
                }
            }
        }
        EmptyState {
            Layout.fillWidth: true
            Layout.fillHeight: true
            iconName: "compass"
            title: "Explore needs a content provider"
            message: "Topic browsing is laid out. Search results and media cards will be wired after the local-first screens are complete."
        }
    }
}
