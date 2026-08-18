"""Voice interface (TTS/STT) from AgenticSeek."""
import logging
import tempfile
from pathlib import Path

logger = logging.getLogger("agent-wun.tools.voice")


def text_to_speech(text: str, output_path: str = None) -> str:
    """Convert text to speech using pyttsx3 (offline)."""
    try:
        import pyttsx3
        engine = pyttsx3.init()
        if not output_path:
            output_path = tempfile.mktemp(suffix=".wav")
        engine.save_to_file(text, output_path)
        engine.runAndWait()
        return output_path
    except ImportError:
        return "pyttsx3 not installed. Install with: pip install pyttsx3"
    except Exception as e:
        return f"TTS error: {e}"


def speech_to_text(audio_path: str) -> str:
    """Convert speech to text using Vosk (offline)."""
    try:
        from vosk import Model, KaldiRecognizer
        import wave
        import json

        model = Model("model")  # User must download model
        wf = wave.open(audio_path, "rb")
        rec = KaldiRecognizer(model, wf.getframerate())
        result = ""
        while True:
            data = wf.readframes(4000)
            if len(data) == 0:
                break
            if rec.AcceptWaveform(data):
                result += json.loads(rec.Result()).get("text", "")
        result += json.loads(rec.FinalResult()).get("text", "")
        return result
    except Exception as e:
        return f"STT error: {e}"
