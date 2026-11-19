import QtQuick
import QtQuick.Layouts
import "../style"

// Centered page frame shared by every library page. Content is capped at the
// dashboard width and falls back to the page inset on narrow windows, matching
// the Home page's gutters.
Item {
    id: frame

    default property alias content: column.data
    property alias spacing: column.spacing
    property int topPadding: Theme.pagePadding
    property int bottomPadding: Theme.pagePadding

    readonly property real contentWidth: width

    width: parent ? Math.min(Theme.pageMaxWidth, parent.width - 2 * Theme.pageInset) : 0
    anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined

    ColumnLayout {
        id: column
        anchors.fill: parent
        anchors.topMargin: frame.topPadding
        anchors.bottomMargin: frame.bottomPadding
    }
}
