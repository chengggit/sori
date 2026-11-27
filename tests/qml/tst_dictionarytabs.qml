import QtQuick
import QtTest
import "../../qml/components" as Components

TestCase {
    id: testCase
    name: "DictionaryTabs"
    when: windowShown
    width: 1000
    height: 700
    visible: true

    Component {
        id: panelComponent
        Components.ReaderAnalysis {
            documentId: 0
            selectedWord: "나무"
            preferredWidth: 320
            maximumWidth: 700
            height: 600
        }
    }

    function makePanel() {
        const panel = createTemporaryObject(panelComponent, testCase)
        verify(panel !== null)
        return panel
    }

    function tabsIn(panel) {
        const tabs = findChild(panel, "dictionaryTabs")
        verify(tabs !== null)
        return tabs
    }

    function wheelOver(view, delta) {
        const center = view.mapToItem(testCase, view.width / 2, view.height / 2)
        mouseWheel(testCase, center.x, center.y, 0, delta)
    }

    function test_tabs_scroll_when_sidebar_is_narrow() {
        const panel = makePanel()
        const tabs = tabsIn(panel)
        const strip = tabs.contentItem
        compare(panel.width, 320)
        compare(tabs.count, 4)
        verify(strip.contentWidth > strip.width)
        compare(strip.clip, true)

        wheelOver(strip, -120)
        verify(strip.contentX > 0)

        wheelOver(strip, -120)
        wheelOver(strip, -120)
        compare(strip.contentX, Math.max(0, strip.originX + strip.contentWidth - strip.width))

        wheelOver(strip, 120)
        verify(strip.contentX < Math.max(0, strip.originX + strip.contentWidth - strip.width))
    }

    function test_last_tab_is_reachable() {
        const panel = makePanel()
        const tabs = tabsIn(panel)
        const strip = tabs.contentItem
        tabs.currentIndex = tabs.count - 1
        verify(strip.contentX > 0)
    }

    function test_wide_sidebar_keeps_tabs_in_place() {
        const panel = makePanel()
        panel.preferredWidth = 700
        tryCompare(panel, "width", 700)
        const tabs = tabsIn(panel)
        const strip = tabs.contentItem
        tryVerify(() => strip.contentWidth <= strip.width + 1, 2000,
            "The resized tab strip should fit all tabs")

        wheelOver(strip, -120)
        compare(strip.contentX, 0)
    }
}
