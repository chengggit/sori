import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../style"

ColumnLayout {
    id: root

    required property var definitions
    property var selected: null
    property int textSize: 14
    property bool expanded: false
    signal chosen(var definition)

    spacing: 4
    onDefinitionsChanged: expanded = false

    Repeater {
        model: root.expanded ? root.definitions : root.definitions.slice(0, 3)

        delegate: Button {
            id: definitionButton

            required property var modelData
            readonly property bool selected: root.selected?.term === modelData.term
                && root.selected?.text === modelData.text && root.selected?.hanja === modelData.hanja

            Layout.fillWidth: true
            Accessible.name: [modelData.hanja, modelData.text].filter(Boolean).join(" ")
            Accessible.checkable: true
            Accessible.checked: selected
            hoverEnabled: true
            padding: 6

            background: Rectangle {
                radius: Theme.radiusSmall
                color: definitionButton.selected ? Theme.accentSoft
                    : definitionButton.hovered ? Theme.neutralHover : "transparent"
                border.width: definitionButton.visualFocus ? 1 : 0
                border.color: Theme.accent
            }

            contentItem: RowLayout {
                spacing: 12
                AppText {
                    visible: !!definitionButton.modelData.hanja
                    text: definitionButton.modelData.hanja ?? ""
                    korean: true
                    color: Theme.mutedForeground
                    Layout.alignment: Qt.AlignTop
                }
                AppText {
                    text: definitionButton.modelData.text
                    font.pixelSize: root.textSize
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                }
            }

            onClicked: root.chosen(modelData)
        }
    }

    Button {
        id: more
        visible: root.definitions.length > 3
        text: root.expanded ? "Show fewer meanings" : qsTr("See %1 more meanings").arg(root.definitions.length - 3)
        Layout.leftMargin: 6
        padding: 0
        topPadding: 4
        bottomPadding: 4
        hoverEnabled: true

        background: Rectangle {
            color: "transparent"
            border.width: more.visualFocus ? 1 : 0
            border.color: Theme.accent
        }

        contentItem: AppText {
            text: more.text
            font.pixelSize: 12
            font.underline: true
            color: more.hovered ? Theme.foreground : Theme.mutedForeground
        }

        onClicked: root.expanded = !root.expanded
    }
}
