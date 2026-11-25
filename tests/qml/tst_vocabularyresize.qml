import QtQuick
import QtTest
import "../../qml/components" as Components

TestCase {
    id: suite
    name: "VocabularyResize"
    when: windowShown
    visible: true
    width: 1200
    height: 800

    Component {
        id: hostComponent
        Item {
            width: 1200
            height: 800
            transformOrigin: Item.TopLeft
            property alias panel: panel
            Components.VocabularyDetails {
                id: panel
                x: parent.width - width
                height: parent.height
                entry: ({word: "학교", context: "학교에 갔어요."})
            }
        }
    }

    function dragEdge(panel, delta) {
        const point = panel.mapToItem(suite, 0, 100)
        mousePress(suite, point.x, point.y)
        mouseMove(suite, point.x + delta, point.y)
        mouseRelease(suite, point.x + delta, point.y)
    }

    function test_drag_width_limits_and_reopen() {
        const host = createTemporaryObject(hostComponent, suite)
        const panel = host.panel
        compare(panel.width, 500)
        dragEdge(panel, -100)
        compare(panel.width, 600)
        dragEdge(panel, -400)
        compare(panel.width, 840)
        dragEdge(panel, 600)
        compare(panel.width, 320)
        panel.visible = false
        panel.visible = true
        compare(panel.width, 320)
        panel.preferredWidth = 600
        host.width = 400
        compare(panel.width, 280)
        host.width = 1200
        compare(panel.width, 600)
    }

    function test_page_zoom() {
        const host = createTemporaryObject(hostComponent, suite, {scale: 0.8})
        dragEdge(host.panel, -80)
        compare(host.panel.width, 600)
    }
}
