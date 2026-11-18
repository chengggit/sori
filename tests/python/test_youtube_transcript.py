import sys
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "scripts"))
from youtube_transcript import fetch
from youtube_transcript_api._errors import TranscriptsDisabled, RequestBlocked


class TranscriptHelperTests(unittest.TestCase):
    def test_language_and_timing(self):
        captions = [SimpleNamespace(start=1.5, duration=2.0, text="한국어"),
                    SimpleNamespace(start=4.0, duration=1.0, text="  ")]
        class Result(list):
            language_code = "ko"
        with patch("youtube_transcript_api.YouTubeTranscriptApi") as api:
            api.return_value.fetch.return_value = Result(captions)
            result = fetch("dQw4w9WgXcQ", "ko")
            api.return_value.fetch.assert_called_once_with("dQw4w9WgXcQ", languages=["ko"])
        self.assertEqual(result, {"language": "ko", "cues": [{"start": 1.5, "end": 3.5, "text": "한국어"}]})

    def test_errors_are_actionable_without_tracebacks(self):
        for error, phrase in [(TranscriptsDisabled("dQw4w9WgXcQ"), "No transcript"),
                              (RequestBlocked("dQw4w9WgXcQ"), "blocked"),
                              (RuntimeError("internal failure"), "Could not fetch")]:
            with self.subTest(error=type(error).__name__):
                with patch("youtube_transcript_api.YouTubeTranscriptApi") as api:
                    api.return_value.fetch.side_effect = error
                    result = fetch("dQw4w9WgXcQ", "ko")
                self.assertIn(phrase, result["error"])
                self.assertNotIn("internal failure", result["error"])
