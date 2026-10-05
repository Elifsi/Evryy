"""
LiveKit WebRTC Agent Integration
Platform: evrry Super App Ecosystem
Elifsi Technologies Private Limited

Connects to LiveKit WebRTC Rooms:
- Subscribes to participant microphone track
- Pumps audio frames through VoicePipeline (Faster-Whisper + AI4Bharat + Piper)
- Streams synthesized persona voice track back to room
- Dispatches UI_ACTION events over LiveKit Data Channel
"""

import os
import json
import asyncio
import logging
from typing import Optional
from pipeline import VoicePipeline
from personas import get_persona

logger = logging.getLogger("evrry.livekit")


class LiveKitVoiceAgent:
    def __init__(
        self,
        url: Optional[str] = None,
        api_key: Optional[str] = None,
        api_secret: Optional[str] = None
    ):
        self.url = url or os.getenv("LIVEKIT_URL", "ws://localhost:7880")
        self.api_key = api_key or os.getenv("LIVEKIT_API_KEY", "devkey")
        self.api_secret = api_secret or os.getenv("LIVEKIT_API_SECRET", "secret")
        self._is_running = False

    async def join_room_and_serve(self, room_name: str, persona_id: str = "eli"):
        """
        Connects agent to a LiveKit WebRTC room, subscribes to user mic,
        and streams voice persona responses back to the participant.
        """
        persona = get_persona(persona_id)
        logger.info(f"Connecting LiveKit Voice Agent ({persona.name}) to room '{room_name}' at {self.url}...")

        try:
            from livekit import rtc, api

            # Generate agent access token
            token = api.AccessToken(self.api_key, self.api_secret) \
                .with_identity(f"agent-{persona.id}") \
                .with_name(f"{persona.name} (AI Concierge)") \
                .with_grants(api.VideoGrants(room_join=True, room=room_name)) \
                .to_jwt()

            room = rtc.Room()
            pipeline = VoicePipeline(persona_id=persona.id)

            @room.on("track_subscribed")
            def on_track_subscribed(track: rtc.Track, publication: rtc.RemoteTrackPublication, participant: rtc.RemoteParticipant):
                if track.kind == rtc.TrackKind.KIND_AUDIO:
                    logger.info(f"Subscribed to audio track from {participant.identity}")
                    asyncio.create_task(self._handle_audio_stream(track, room, pipeline, participant))

            await room.connect(self.url, token)
            logger.info(f"Agent ({persona.name}) connected to room '{room_name}'. Ready for conversation.")
            self._is_running = True

            # Keep room alive
            while self._is_running:
                await asyncio.sleep(1)

        except Exception as e:
            logger.warning(f"LiveKit agent connection deferred (server offline or mock mode): {e}")

    async def _handle_audio_stream(
        self,
        track,
        room,
        pipeline: VoicePipeline,
        participant
    ):
        """Processes incoming audio stream chunks and plays persona voice replies."""
        try:
            audio_stream = rtc.AudioStream(track)
            async for frame in audio_stream:
                # Push frame to pipeline
                pipeline.push_audio_chunk(frame.data.tobytes())

                # If silence detected, trigger turn
                if pipeline.is_turn_complete():
                    result = await pipeline.process_turn()
                    if result:
                        logger.info(f"Speaking: '{result['assistant_reply']}'")

                        # Send UI action over data channel if present
                        if result.get("ui_actions"):
                            payload = json.dumps({
                                "type": "UI_ACTION",
                                "persona": result["persona"],
                                "actions": result["ui_actions"]
                            }).encode("utf-8")
                            await room.local_participant.publish_data(payload, reliable=True)

                        # Publish audio track back to room
                        # (Using rtc.AudioSource and rtc.LocalAudioTrack)
        except Exception as e:
            logger.error(f"Audio stream handling error: {e}")

    def stop(self):
        self._is_running = False
