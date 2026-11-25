pragma Singleton
import QtQuick

QtObject {
    property var cachedTranscript: null
    function cacheYoutubeTranscript(id, data) {
        cachedTranscript = data
        return {ok: true, data: null, error: ""}
    }
    function readYoutubeTranscript(id) {
        return {ok:true,error:"",data: {
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
        }};
    }
}
