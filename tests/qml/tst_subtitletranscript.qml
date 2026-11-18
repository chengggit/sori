import QtQuick
import QtTest
import "../../qml/components" as Components

TestCase {
    id: testCase
    name: "TranscriptFollow"
    when: windowShown
    visible: true
    width: 800
    height: 500

    QtObject {
        id: fakeSubtitles
        property var transcript: []
        property int activeRow: 0
        property bool loading: false
    }
    QtObject {
        id: fakePlayer
        property real position: 0
        function formatTime(time) { return String(time) }
        function seek(time) { position = time; fakeSubtitles.activeRow = Math.floor(time / 3) }
    }
    Components.SubtitleTranscript {
        id: transcript
        anchors.fill: parent
        subtitles: fakeSubtitles
        player: fakePlayer
    }
    Timer {
        id: playback
        interval: 100
        repeat: true
        onTriggered: {
            fakePlayer.position += 0.1
            fakeSubtitles.activeRow = Math.floor(fakePlayer.position / 3)
        }
    }

    function initTestCase() {
        const rows = []
        for (let i = 0; i < 100; i++)
            rows.push({start: i * 3, end: i * 3 + 2, text: "한국어 자막입니다. ".repeat(1 + i % 12) + i})
        fakeSubtitles.transcript = rows
        wait(800)
    }
    function test_follow() {
        const list = findChild(transcript, "subtitleTranscript")
        verify(list !== null)
        fakeSubtitles.activeRow = 3
        wait(750)
        verify(Math.abs(list.contentY - list.itemAtIndex(3).y) < 2, "The current line should settle at the top")

        // A playback seek outside the instantiated delegate range must animate.
        const before = list.contentY
        fakeSubtitles.activeRow = 80
        wait(100)
        const halfway = list.contentY
        verify(halfway > before + 5)
        wait(650)
        verify(list.contentY > halfway + 100)
        tryVerify(() => list.itemAtIndex(80) !== null && Math.abs(list.contentY - list.itemAtIndex(80).y) < 2, 1500)
        verify(transcript.following)

        mouseWheel(list, 200, 100, 0, -120)
        verify(!transcript.following)
        wait(250)
        list.cancelFlick()
        list.positionViewAtIndex(30, ListView.Beginning)
        list.forceLayout()
        wait(50)
        verify(!transcript.following)
        const row = list.itemAtIndex(31)
        verify(row !== null)
        const button = row.children[0]
        const oldY = list.contentY
        button.clicked()
        verify(transcript.following)
        compare(fakePlayer.position, 93)
        compare(list.contentY, oldY)
        wait(100)
        verify(list.contentY > oldY)
        wait(650)
        verify(Math.abs(list.contentY - list.itemAtIndex(31).y) < 2)

        const resume = findChild(transcript, "resumeTranscriptFollow")
        verify(resume !== null)
        verify(!resume.visible)
        mouseWheel(list, 200, 100, 0, -120)
        verify(!transcript.following)
        tryVerify(() => resume.visible, 400)
        wait(250)
        mouseClick(resume)
        verify(transcript.following)
        tryVerify(() => !resume.visible, 400)
        tryVerify(() => list.itemAtIndex(fakeSubtitles.activeRow) !== null
            && Math.abs(list.contentY - list.itemAtIndex(fakeSubtitles.activeRow).y) < 2, 1500)

        // Exercise real wheel input while playback keeps updating under a
        // stationary pointer. Hover updates must not reset the idle deadline.
        mouseMove(list, 200, 100)
        mouseWheel(list, 200, 100, 0, -120)
        verify(!transcript.following)
        fakePlayer.position = 210
        playback.start()
        wait(4300)
        verify(!transcript.following, "Following must stay paused before five seconds")
        tryCompare(transcript, "following", true, 1600)
        playback.stop()
        tryVerify(() => list.itemAtIndex(fakeSubtitles.activeRow) !== null
            && Math.abs(list.contentY - list.itemAtIndex(fakeSubtitles.activeRow).y) < 2, 2000)

        fakeSubtitles.activeRow = 99
        wait(750)
        tryVerify(() => list.itemAtIndex(99) !== null && Math.abs(list.contentY - list.itemAtIndex(99).y) < 2, 1500, "The last line should also reach the top")
    }
}
