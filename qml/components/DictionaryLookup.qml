import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import sori_qt_playback
import "../style"

Dialog {
    id: root
    property string term: ""
    readonly property string lookupUrl: {
        const provider = DictionaryTabs.enabled[tabs.currentIndex]
        return provider ? Analysis.dictionaryLookupUrl(provider.template, encodeURIComponent(term.trim())) : ""
    }

    title: term
    modal: true
    standardButtons: Dialog.Close
    anchors.centerIn: parent
    width: Math.min(900, parent.width - 32)
    height: Math.min(680, parent.height - 32)

    contentItem: ColumnLayout {
        TabBar {
            id: tabs
            Layout.fillWidth: true

            Repeater {
                model: DictionaryTabs.enabled
                delegate: TabButton {
                    required property var modelData
                    text: modelData.label
                    width: implicitWidth
                }
            }
        }

        DictionaryLookupView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            lookupUrl: root.lookupUrl
        }
    }
}
