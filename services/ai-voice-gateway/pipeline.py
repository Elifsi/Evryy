"""
Real-Time Voice Pipeline with Interruption & VAD
Platform: evrry Super App Ecosystem
Elifsi Technologies Private Limited

Coordinates:
- 16kHz PCM audio chunk aggregation
- Voice Activity Detection (VAD) & End-of-Turn detection (400ms silence)
- Barge-in / Interruption cancellation
- Streaming TTS & UI Action dispatch
"""

import io
import time
import asyncio
import logging
from typing import Optional, Dict, Any, AsyncGenerator
from personas import VoicePersona, get_persona
from asr_engine import AsrEngine
from tts_engine import TtsEngine
from dialog_orchestrator import DialogOrchestrator

logger = logging.getLogger("evrry.pipeline")


class VoicePipeline:
    def __init__(
        self,
        persona_id: str = "eli",
        sample_rate: int = 16000,
        silence_threshold_sec: float = 0.45
    ):
        self.persona = get_persona(persona_id)
        self.sample_rate = sample_rate
        self.silence_threshold_sec = silence_threshold_sec

        self.asr = AsrEngine()
        self.tts = TtsEngine(sample_rate=sample_rate)
        self.dialog = DialogOrchestrator()

        self._audio_buffer = bytearray()
        self._is_speaking = False
        self._last_speech_time = 0.0
        self._is_interrupted = False

    def set_persona(self, persona_id: str):
        """Dynamically switch voice persona during a session."""
        self.persona = get_persona(persona_id)
        logger.info(f"Pipeline switched to persona: {self.persona.name}")

    def interrupt(self):
        """Barge-in triggered: user spoke while assistant was playing audio."""
        self._is_interrupted = True
        logger.info("Barge-in detected: interrupting assistant playback.")

    def push_audio_chunk(self, chunk: bytes) -> bool:
        """
        Append audio chunk to buffer and monitor energy for VAD.
        Returns True if speech was detected.
        """
        self._audio_buffer.extend(chunk)

        # Basic energy-based VAD (Voice Activity Detection)
        if len(chunk) >= 640:
            # Inspect first 100 samples
            import struct
            samples = struct.unpack(f"{len(chunk)//2}h", chunk)
            energy = sum(abs(s) for s in samples) / len(samples)

            if energy > 400:  # Active speech
                if not self._is_speaking:
                    self._is_speaking = True
                    self.interrupt()
                self._last_speech_time = time.time()
                return True

        return False

    def is_turn_complete(self) -> bool:
        """Check if speaker has concluded utterance (silence threshold passed)."""
        if self._is_speaking and self._last_speech_time > 0:
            silence_duration = time.time() - self._last_speech_time
            if silence_duration >= self.silence_threshold_sec and len(self._audio_buffer) >= 3200:
                return True
        return False

    async def process_turn(
        self,
        user_context: Optional[Dict[str, Any]] = None
    ) -> Optional[Dict[str, Any]]:
        """
        Transcribes buffered audio, executes dialog loop, and synthesizes persona speech.
        """
        if len(self._audio_buffer) < 3200:
            self._reset_turn()
            return None

        audio_bytes = bytes(self._audio_buffer)
        self._reset_turn()
        self._is_interrupted = False

        # 1. Automatic Speech Recognition
        transcribed_text, devanagari_text = self.asr.transcribe(audio_bytes)
        if not transcribed_text:
            return None

        logger.info(f"[{self.persona.name}] Transcribed: '{transcribed_text}' (Devanagari: '{devanagari_text}')")

        # 2. Dialog Orchestration & Tools
        dialog_res = await self.dialog.generate_response(
            user_text=transcribed_text,
            persona=self.persona,
            user_context=user_context
        )

        reply_text = dialog_res.get("text", "")
        ui_actions = dialog_res.get("ui_actions", [])

        # 3. Neural Speech Synthesis with Persona Pitch & Speed
        pcm_audio = self.tts.synthesize(reply_text, self.persona)

        return {
            "user_text": transcribed_text,
            "devanagari_text": devanagari_text,
            "assistant_reply": reply_text,
            "persona": self.persona.id,
            "persona_name": self.persona.name,
            "pcm_audio": pcm_audio,
            "ui_actions": ui_actions
        }

    def _reset_turn(self):
        """Clear current speech buffer for next utterance."""
        self._audio_buffer.clear()
        self._is_speaking = False
        self._last_speech_time = 0.0
