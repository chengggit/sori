import QtQuick
import QtTest
import "../../qml/components" as Components

TestCase {
    id: testCase
    name: "DictionaryRetention"
    when: windowShown
    width: 1200
    height: 800

    Component {
        id: panelComponent
        Components.ReaderAnalysis {
            documentId: 0
            dictionaryRetentionMs: 100
        }
    }

    function test_closed_pages_expire() {
        const panel = createTemporaryObject(panelComponent, testCase)
        const pages = findChild(panel, "embeddedDictionaryPages")
        compare(pages.count, 0)
        panel.selectedWord = "나무"
        verify(pages.count > 0)
        const count = pages.count
        const firstPage = pages.itemAt(0)
        panel.close()
        compare(pages.count, count)
        compare(pages.itemAt(0), firstPage)
        tryCompare(pages, "count", 0)
    }

    function test_reopening_cancels_expiry() {
        const panel = createTemporaryObject(panelComponent, testCase)
        panel.selectedWord = "나무"
        const pages = findChild(panel, "embeddedDictionaryPages")
        const firstPage = pages.itemAt(0)
        panel.close()
        panel.selectedWord = "학교"
        wait(150)
        compare(pages.itemAt(0), firstPage)
        panel.close()
        tryCompare(pages, "count", 0)
    }
}
