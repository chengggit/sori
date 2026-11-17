import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../style"
import "../components"

Popup {
    id: root

    DictionarySettings { id: dictionarySettings; parent: root.parent }

    width: Math.min(420, parent ? parent.width - 40 : 420)
    x: parent ? Math.round((parent.width - width) / 2) : 0
    y: parent ? Math.round((parent.height - height) / 2) : 0
    modal: true
    focus: true
    padding: 0

    background: Rectangle {
        radius: 16
        color: Theme.card
        border.width: 1
        border.color: Theme.border
    }

    contentItem: ColumnLayout {
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.margins: 20
            spacing: 12
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                AppText { text: "Settings"; font.pixelSize: 19; font.weight: Font.DemiBold }
            }
            AppButton {
                text: ""
                iconName: "x"
                variant: "ghost"
                implicitWidth: 34
                onClicked: root.close()
            }
        }

        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.border }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.margins: 20
            spacing: 12

            AppText { text: "Appearance"; font.weight: Font.DemiBold; font.pixelSize: 13 }
            RowLayout {
                spacing: 8
                Repeater {
                    model: [
                        { value: "system", label: "System" },
                        { value: "light", label: "Light" },
                        { value: "dark", label: "Dark" }
                    ]
                    delegate: AppButton {
                        required property var modelData
                        text: modelData.label
                        small: true
                        variant: Theme.appearance === modelData.value ? "secondary" : "outline"
                        onClicked: Theme.appearance = modelData.value
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.border }

            AppButton {
                text: "Dictionary tabs"
                variant: "outline"
                onClicked: dictionarySettings.open()
            }
        }
    }
}
