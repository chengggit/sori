import QtQuick
import QtQuick.Controls
import QtTest
import "../../qml/components" as Components

TestCase {
    id: testCase
    name: "AnalysisResize"
    when: windowShown
    visible: true
    width: 1200
    height: 800

    Component {
        id: scaledHostComponent
        Item {
            width: 1200
            height: 800
            scale: 0.8
            transformOrigin: Item.TopLeft
        }
    }

    Component {
        id: drawerComponent
        Drawer {
            id: drawer
            edge: Qt.RightEdge
            width: Math.min(details.preferredWidth, details.maximumWidth)
            height: testCase.height
            padding: 0
            dragMargin: 0
            enter: Transition {}
            exit: Transition {}
            Components.ReaderAnalysis {
                id: details
                objectName: "drawerAnalysis"
                documentId: 0
                selectedWord: "나무"
                anchors.fill: parent
                maximumWidth: testCase.width * 0.7
            }
        }
    }

    Component {
        id: panelComponent
        Components.ReaderAnalysis {
            documentId: 0
            selectedWord: "나무"
            anchors.right: parent.right
            height: parent.height
        }
    }

    function makePanel() {
        const panel = createTemporaryObject(panelComponent, testCase)
        verify(panel !== null)
        return panel
    }

    function dragEdge(panel, delta) {
        const start = panel.mapToItem(testCase, 0, 100)
        mousePress(testCase, start.x, start.y)
        mouseMove(testCase, start.x + delta, start.y)
        mouseRelease(testCase, start.x + delta, start.y)
    }

    function test_drag_in_both_directions() {
        const panel = makePanel()
        compare(panel.width, 500)
        dragEdge(panel, -100)
        compare(panel.width, 600)
        dragEdge(panel, 150)
        compare(panel.width, 450)
        compare(panel.x + panel.width, testCase.width)
    }

    function test_drag_limits_and_reopen() {
        const panel = makePanel()
        dragEdge(panel, -500)
        compare(panel.width, panel.maximumWidth)
        dragEdge(panel, 700)
        compare(panel.width, panel.minimumWidth)
        panel.close()
        panel.selectedWord = "다시"
        compare(panel.width, 320)
    }

    function test_window_shrink_preserves_preference() {
        const panel = makePanel()
        panel.maximumWidth = 250
        compare(panel.width, 250)
        compare(panel.minimumWidth, 250)
        panel.maximumWidth = 840
        compare(panel.width, 500)
    }

    function test_resize_with_page_zoom() {
        const host = createTemporaryObject(scaledHostComponent, testCase)
        const panel = createTemporaryObject(panelComponent, host)
        verify(panel !== null)
        dragEdge(panel, -80)
        compare(panel.width, 600)
    }

    function test_fullscreen_drawer_resize() {
        const drawer = createTemporaryObject(drawerComponent, testCase)
        verify(drawer !== null)
        drawer.open()
        tryCompare(drawer, "opened", true)
        const panel = findChild(drawer, "drawerAnalysis")
        verify(panel !== null)
        dragEdge(panel, -100)
        // Drawer styles may inset their content by a pixel.
        verify(Math.abs(drawer.width - 600) <= 1)
        compare(drawer.opened, true)
        drawer.close()
    }
}
