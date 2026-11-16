import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../Theme.js" as Theme
import "../components"

Popup {
    id: root

    property string appearance: "system"
    required property bool nativeText
    signal nativeTextRequested(bool enabled)

    width: Math.min(420, parent ? parent.width - 40 : 420)
    height: Math.min(520, parent ? parent.height - 40 : 520)
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
                AppText {
                    text: "Customize appearance and reading."
                    color: Theme.mutedForeground
                    font.pixelSize: 13
                }
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
                        variant: root.appearance === modelData.value ? "secondary" : "outline"
                        onClicked: root.appearance = modelData.value
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.border }

            AppText { text: "Text rendering"; font.weight: Font.DemiBold; font.pixelSize: 13 }
            CheckBox {
                text: "Use native text rendering"
                checked: root.nativeText
                onToggled: root.nativeTextRequested(checked)
            }
            AppText {
                Layout.fillWidth: true
                text: "Dictionary and embedded lookup preferences will move here with the reader frontend."
                color: Theme.mutedForeground
                font.pixelSize: 12
                wrapMode: Text.Wrap
            }
            Item { Layout.fillHeight: true }
        }
    }
}
