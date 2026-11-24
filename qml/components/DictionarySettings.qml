import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import sori_core
import "../style"

Dialog {
    id: root

    title: "Dictionary tabs"
    modal: true
    standardButtons: Dialog.Close
    anchors.centerIn: parent
    width: Math.min(540, parent.width - 32)
    height: Math.min(440, parent.height - 32)

    contentItem: ColumnLayout {
        ListView {
            model: DictionaryTabs.providers
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            ScrollBar.vertical: AppScrollBar {}

            delegate: RowLayout {
                required property var modelData
                required property int index
                width: ListView.view.width

                CheckBox {
                    text: modelData.label
                    checked: DictionaryTabs.enabled.some(provider => provider.template === modelData.template)
                    Layout.fillWidth: true
                    onToggled: DictionaryTabs.setEnabled(modelData.template, checked)
                }

                AppButton {
                    visible: index >= 2
                    text: "Remove"
                    variant: "ghost"
                    small: true
                    onClicked: DictionaryTabs.remove(modelData.template)
                }
            }
        }

        AppInput {
            id: labelField
            placeholderText: "Dictionary name"
            Accessible.name: placeholderText
            Layout.fillWidth: true
        }

        AppInput {
            id: urlField
            placeholderText: "HTTPS lookup URL with {word}"
            Accessible.name: placeholderText
            Layout.fillWidth: true
        }

        AppText {
            id: errorText
            visible: !!text
            color: Theme.destructive
            wrapMode: Text.Wrap
            Layout.fillWidth: true
        }

        AppButton {
            text: "Add dictionary"
            enabled: !!labelField.text.trim() && !!urlField.text.trim()
            onClicked: {
                const template = urlField.text.trim()
                if (!Analysis.dictionaryLookupUrl(template, "test").data) {
                    errorText.text = "Enter an HTTPS address without a username or password."
                } else if (DictionaryTabs.providers.some(provider => provider.template === template)) {
                    errorText.text = "That dictionary is already listed."
                } else {
                    DictionaryTabs.add(labelField.text.trim(), template)
                    errorText.text = ""
                    labelField.clear()
                    urlField.clear()
                }
            }
        }
    }
}
