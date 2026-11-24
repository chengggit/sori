pragma Singleton
import QtQuick

QtObject {
    function readYoutubeTranscript(id) {
        return {
            language: "ko",
            cues: [
                {
                    start: 0,
                    end: 4,
                    text: "first"
                },
                {
                    start: 5,
                    end: 9,
                    text: "second"
                }
            ]
        };
    }
}
