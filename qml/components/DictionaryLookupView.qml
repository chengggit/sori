import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../style"

ColumnLayout {
    id: root

    required property string lookupUrl
    property bool keepLoaded: false

    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: 20
        Layout.rightMargin: 24
        Layout.topMargin: 8

        AppText {
            id: statusMessage
            visible: text !== ""
            text: web.status === Loader.Error || !DictionaryTabs.webEngineAvailable
                ? "Open this dictionary in your browser."
                : web.item?.loadError ?? ""
            color: Theme.mutedForeground
            wrapMode: Text.Wrap
            Layout.fillWidth: true
        }

        Item {
            visible: !statusMessage.visible
            Layout.fillWidth: true
        }

        Button {
            id: browserLink

            text: "Open in browser"
            enabled: !!root.lookupUrl
            padding: 0
            topPadding: 6
            bottomPadding: 6
            hoverEnabled: true
            Accessible.role: Accessible.Link

            background: Rectangle {
                color: "transparent"
                border.width: browserLink.visualFocus ? 1 : 0
                border.color: Theme.accent
            }

            contentItem: AppText {
                text: browserLink.text
                font.pixelSize: 12
                font.underline: true
                color: browserLink.hovered ? Theme.foreground : Theme.mutedForeground
            }

            onClicked: Qt.openUrlExternally(root.lookupUrl)
        }
    }

    Loader {
        id: web
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: status === Loader.Ready
        active: (root.visible || root.keepLoaded) && DictionaryTabs.webEngineAvailable && !!root.lookupUrl
        source: "DictionaryWebView.qml"
        onLoaded: item.url = Qt.binding(() => root.lookupUrl)
    }

    Item {
        visible: web.status !== Loader.Ready
        Layout.fillHeight: true
    }
}
