pragma Singleton
import QtQuick

QtObject {
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
