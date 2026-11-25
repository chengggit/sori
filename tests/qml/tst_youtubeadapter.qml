import QtQuick
import QtTest
import sori_core
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
    function test_transcript_replies_keep_payload_and_error_separate() {
        const page = createTemporaryObject(pageComponent, testCase, {width:1200,height:800})
        verify(page !== null)
        tryCompare(findChild(page, "subtitleTranscript"), "count", 2)
        Library.cachedTranscript = null
        page.fetchRequest = 101
        YouTube.transcriptFinished(100, {ok:false, data:null, error:"Stale error"})
        compare(page.fetchRequest, 101)
        compare(page.transcriptError, "")
        YouTube.transcriptFinished(101, {ok:false, data:null, error:"No connection"})
        compare(page.transcriptError, "No connection")
        compare(Library.cachedTranscript, null)
        page.fetchRequest = 102
        const data = {language:"ko", cues:[{start:0,end:5,text:"새로운 자막"}]}
        YouTube.transcriptFinished(102, {ok:true, data:data, error:""})
        compare(page.transcriptError, "")
        compare(page.savedTranscript.cues[0].text, "새로운 자막")
        compare(Library.cachedTranscript.language, "ko")
        compare(Library.cachedTranscript.cues[0].text, "새로운 자막")
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
