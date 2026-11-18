"""Optional JSON-only helper; Qt and application state remain in Rust/QML."""

import json
import sys


def fetch(video_id, language):
    try:
        from requests import Session
        from youtube_transcript_api import YouTubeTranscriptApi
        from youtube_transcript_api._errors import (
            NoTranscriptFound,
            RequestBlocked,
            TranscriptsDisabled,
            VideoUnavailable,
        )
    except ImportError:
        return {
            "error": "Transcript helper is not installed. Run the YouTube transcript setup in README.md."
        }

    class TimedSession(Session):
        def request(self, *args, **kwargs):
            kwargs.setdefault("timeout", 10)
            return super().request(*args, **kwargs)

    try:
        transcript = YouTubeTranscriptApi(http_client=TimedSession()).fetch(
            video_id, languages=[language]
        )
        return {
            "language": transcript.language_code,
            "cues": [
                {"start": cue.start, "end": cue.start + cue.duration, "text": cue.text}
                for cue in transcript
                if cue.text.strip() and cue.duration > 0
            ],
        }
    except (TranscriptsDisabled, NoTranscriptFound):
        return {
            "error": "No transcript is available in this language. Try another language or attach a TXT file."
        }
    except RequestBlocked:
        return {
            "error": "YouTube blocked the transcript request. Try again later or attach a TXT file."
        }
    except VideoUnavailable:
        return {"error": "This video is unavailable for transcript fetching."}
    except Exception:
        return {
            "error": "Could not fetch the transcript from YouTube. Try again later or attach a TXT file."
        }


if __name__ == "__main__":
    if sys.argv[1:] == ["--self-test"]:
        from importlib.metadata import version
        from youtube_transcript_api import YouTubeTranscriptApi
        print(json.dumps({"ready": True, "version": version("youtube-transcript-api")}))
    else:
        print(json.dumps(fetch(sys.argv[1], sys.argv[2]), ensure_ascii=False))
