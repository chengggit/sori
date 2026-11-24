import QtQuick
import QtTest
import "../../qml/components" as Components

TestCase {
    id: testCase
    name: "TranscriptHeaderActions"
    when: windowShown
    visible: true
    width: 800
    height: 300
    Components.TranscriptHeader { id: header; width: 700; x: 24; y: 24 }
    SignalSpy { id: addSpy; target: header; signalName: "addRequested" }
    SignalSpy { id: removeSpy; target: header; signalName: "removeRequested" }
    function test_attachment_actions_stay_in_header() {
        const add = findChild(header, "addTranscriptButton")
        const more = findChild(header, "transcriptMoreButton")
        verify(add.visible)
        verify(!more.visible)
        add.clicked()
        compare(addSpy.count, 1)
        header.hasText = true
        verify(!add.visible)
        verify(more.visible)
        more.clicked()
        const menu = findChild(header, "transcriptOptions")
        tryCompare(menu, "visible", true)
        findChild(header, "replaceTranscriptAction").triggered()
        compare(addSpy.count, 2)
        findChild(header, "removeTranscriptAction").triggered()
        compare(removeSpy.count, 1)
        menu.close()
    }
}
