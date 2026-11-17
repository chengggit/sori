import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes
import sori_qt_playback
import "../style"
import "../components"

Popup {
    id: root

    property string dictionaryError: ""

    width: Math.min(510, parent ? parent.width - 40 : 510)
    implicitHeight: header.implicitHeight + 40 + 1 + settingsScroll.contentHeight
    height: Math.min(implicitHeight, 520, parent ? parent.height - 32 : 520)
    x: parent ? Math.round((parent.width - width) / 2) : 0
    y: parent ? Math.round((parent.height - height) / 2) : 0
    modal: true
    focus: true
    padding: 0
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    function addDictionary() {
        const label = labelField.text.trim()
        const template = urlField.text.trim()
        if (!label || !template)
            return
        if (!Analysis.dictionaryLookupUrl(template, "test")) {
            dictionaryError = "Enter an HTTPS address without a username or password."
        } else if (DictionaryTabs.providers.some(provider => provider.template === template)) {
            dictionaryError = "That dictionary is already listed."
        } else {
            DictionaryTabs.add(label, template)
            dictionaryError = ""
            labelField.clear()
            urlField.clear()
        }
    }

    component SettingsCheck: CheckBox {
        id: check

        Layout.fillWidth: true
        Layout.preferredHeight: 24
        spacing: 8
        padding: 0
        hoverEnabled: true

        contentItem: AppText {
            leftPadding: check.indicator.width + check.spacing
            text: check.text
            font.pixelSize: 14
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }

        indicator: Rectangle {
            x: check.leftPadding
            y: (check.height - height) / 2
            implicitWidth: 16
            implicitHeight: 16
            radius: 4
            color: check.checked ? Theme.accent : Theme.card
            border.width: check.checked ? 0 : 1
            border.color: check.hovered ? Theme.mutedForeground : Theme.border

            Shape {
                anchors.fill: parent
                visible: check.checked
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    strokeWidth: 2
                    strokeColor: Theme.dark ? "#000000" : "#ffffff"
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    joinStyle: ShapePath.RoundJoin
                    PathSvg { path: "M 4 8 L 7 11 L 12 5" }
                }
            }
        }
    }

    background: Rectangle {
        radius: Theme.radiusLarge
        color: Theme.card
        border.width: 1
        border.color: Theme.border
    }

    contentItem: ColumnLayout {
        spacing: 0

        RowLayout {
            id: header
            Layout.fillWidth: true
            Layout.margins: 20
            spacing: 12

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                AppText {
                    Layout.fillWidth: true
                    text: "Settings"
                    font.pixelSize: 18
                    font.weight: Font.DemiBold
                }

                AppText {
                    Layout.fillWidth: true
                    text: "Customize appearance and dictionary lookups."
                    color: Theme.mutedForeground
                    wrapMode: Text.Wrap
                }
            }

            AppButton {
                text: ""
                iconName: "x"
                variant: "ghost"
                Layout.alignment: Qt.AlignTop
                Layout.preferredWidth: 30
                Layout.preferredHeight: 30
                Accessible.name: "Close settings"
                onClicked: root.close()
            }
        }

        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.border }

        AppScrollView {
            id: settingsScroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: availableWidth
            contentHeight: form.implicitHeight + 40
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            clip: true

            ColumnLayout {
                id: form
                x: 20
                y: 20
                width: settingsScroll.availableWidth - 40
                spacing: 20

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    AppText {
                        text: "Appearance"
                        font.weight: Font.DemiBold
                    }

                    ComboBox {
                        id: appearance
                        Layout.fillWidth: true
                        implicitHeight: Theme.inputHeight
                        leftPadding: 12
                        rightPadding: 36
                        topPadding: 0
                        bottomPadding: 0
                        Accessible.name: "Appearance"
                        model: [
                            { value: "system", label: "System" },
                            { value: "light", label: "Light" },
                            { value: "dark", label: "Dark" }
                        ]
                        textRole: "label"
                        valueRole: "value"
                        currentIndex: Math.max(0, model.findIndex(entry => entry.value === Theme.appearance))
                        onActivated: index => Theme.appearance = model[index].value

                        contentItem: AppText {
                            text: appearance.displayText
                            font.pixelSize: 13
                            verticalAlignment: Text.AlignVCenter
                        }

                        indicator: Icon {
                            x: appearance.width - width - 12
                            y: (appearance.height - height) / 2
                            name: "chevron-down"
                            size: 14
                            color: Theme.mutedForeground
                        }

                        background: Rectangle {
                            radius: Theme.radius
                            color: Theme.card
                            border.width: appearance.activeFocus ? 2 : 1
                            border.color: appearance.activeFocus ? Theme.accent : Theme.border
                        }

                        delegate: ItemDelegate {
                            required property int index
                            width: appearance.width - appearance.popup.leftPadding - appearance.popup.rightPadding
                            implicitHeight: Theme.compactControlHeight
                            padding: 8
                            highlighted: appearance.highlightedIndex === index
                            hoverEnabled: true

                            contentItem: AppText {
                                text: appearance.textAt(index)
                                font.pixelSize: 13
                                verticalAlignment: Text.AlignVCenter
                            }
                            background: Rectangle {
                                radius: Theme.radiusSmall
                                color: parent.highlighted || parent.hovered ? Theme.neutralHover : "transparent"
                            }
                        }

                        popup: Popup {
                            y: appearance.height + 4
                            width: appearance.width
                            padding: 4

                            background: Rectangle {
                                color: Theme.card
                                radius: Theme.radius
                                border.width: 1
                                border.color: Theme.border
                            }

                            contentItem: ListView {
                                implicitHeight: contentHeight
                                model: appearance.delegateModel
                                currentIndex: appearance.highlightedIndex
                                clip: true
                            }
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    AppText {
                        text: "Embedded lookup tabs"
                        font.weight: Font.DemiBold
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Repeater {
                            model: DictionaryTabs.providers

                            delegate: RowLayout {
                                required property var modelData
                                required property int index
                                Layout.fillWidth: true
                                spacing: Theme.controlGap

                                SettingsCheck {
                                    text: parent.modelData.label
                                    checked: DictionaryTabs.enabled.some(provider => provider.template === parent.modelData.template)
                                    onToggled: DictionaryTabs.setEnabled(parent.modelData.template, checked)
                                }

                                AppButton {
                                    visible: parent.index >= 2
                                    iconName: "x"
                                    variant: "ghost"
                                    Layout.preferredWidth: 24
                                    Layout.preferredHeight: 24
                                    Accessible.name: "Remove " + parent.modelData.label
                                    onClicked: DictionaryTabs.remove(parent.modelData.template)
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 4
                        spacing: Theme.controlGap

                        AppInput {
                            id: labelField
                            Layout.preferredWidth: 120
                            placeholderText: "Name"
                            Accessible.name: placeholderText
                        }

                        AppInput {
                            id: urlField
                            Layout.fillWidth: true
                            placeholderText: "HTTPS URL with {word}"
                            Accessible.name: placeholderText
                            onAccepted: root.addDictionary()
                        }

                        AppButton {
                            text: ""
                            iconName: "plus"
                            variant: "outline"
                            Layout.preferredWidth: Theme.inputHeight
                            Layout.preferredHeight: Theme.inputHeight
                            Accessible.name: "Add dictionary"
                            enabled: !!labelField.text.trim() && !!urlField.text.trim()
                            onClicked: root.addDictionary()
                        }
                    }

                    AppText {
                        visible: !!root.dictionaryError
                        text: root.dictionaryError
                        color: Theme.destructive
                        font.pixelSize: 12
                        wrapMode: Text.Wrap
                        Layout.fillWidth: true
                    }

                    AppText {
                        text: "Use {word} for the selected word. HTTPS URLs are supported."
                        color: Theme.mutedForeground
                        font.pixelSize: 12
                        wrapMode: Text.Wrap
                        Layout.fillWidth: true
                    }
                }
            }
        }
    }
}
