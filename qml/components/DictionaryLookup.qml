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
        RowLayout {
            Layout.fillWidth: true
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

            AppButton {
                text: "Open in browser"
                enabled: !!root.lookupUrl
                variant: "outline"
                onClicked: Qt.openUrlExternally(root.lookupUrl)
            }
        }

        Loader {
            id: web
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: status === Loader.Ready
            active: root.visible && DictionaryTabs.webEngineAvailable && !!root.lookupUrl
            source: "DictionaryWebView.qml"
            onLoaded: item.url = Qt.binding(() => root.lookupUrl)
        }

        AppText {
            visible: web.status !== Loader.Ready && !!root.lookupUrl
            text: "You can open this dictionary in your browser."
            Layout.fillWidth: true
            Layout.fillHeight: true
            wrapMode: Text.Wrap
        }
    }
}
