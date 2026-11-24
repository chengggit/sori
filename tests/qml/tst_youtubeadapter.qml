import QtQuick
import QtTest
import "../../qml/pages" as Pages

TestCase {
    id: testCase
    name: "YouTubeTranscriptAdapter"
    when: windowShown
    visible: true
    width: 1200
    height: 800
    QtObject {
        id: host
        function setReadingLineHeight(document, height) {
        }
    }
    Component {
        id: pageComponent
        Pages.YouTubeWatchPage {
            embeddingAvailable: false
            renderHost: host
            video: ({
                    youtubeId: "dQw4w9WgXcQ",
                    youtubeUrl: "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
                    title: "Example",
                    seconds: 6
                })
        }
    }
    function test_resume_and_playback_refresh() {
        const page = createTemporaryObject(pageComponent, testCase, {
            width: 1200,
            height: 800
        });
        verify(page !== null);
        const loader = findChild(page, "youtubePlayerLoader");
        verify(loader !== null);
        loader.source = "";
        loader.sourceComponent = Qt.createComponent("mocks/FakeYouTubePlayer.qml");
        loader.active = true;
        tryVerify(() => loader.item !== null);
        const lines = findChild(page, "subtitleTranscript");
        verify(lines !== null);
        tryCompare(lines, "count", 2);
        let transcript = lines.parent;
        while (transcript && transcript.subtitles === undefined)
            transcript = transcript.parent;
        verify(transcript !== null);
        tryCompare(transcript.subtitles, "activeRow", 1);
        loader.item.checkpoint(page.video, 0, 20);
        compare(transcript.subtitles.activeRow, 0);
        loader.item.checkpoint(page.video, 6, 20);
        compare(transcript.subtitles.activeRow, 1);
    }
}
