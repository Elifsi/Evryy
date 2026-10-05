"""
AI Voice Gateway Service — FastAPI & WebSocket Engine
Platform: evrry Super App Ecosystem
Elifsi Technologies Private Limited

Endpoints:
- GET /health: Status & Persona availability
- GET /personas: Catalog of 4 Voice Personas (Eli, Rony, Jenny, Suka)
- POST /token: LiveKit WebRTC room token generation
- WebSocket /ws/voice-agent: Direct full-duplex low-latency audio streaming
"""

import os
import json
import logging
from contextlib import asynccontextmanager
from typing import Optional, List

from fastapi import FastAPI, WebSocket, WebSocketDisconnect, Query, HTTPException, Depends
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

from personas import get_all_personas, get_persona, VoicePersona
from pipeline import VoicePipeline

# Logging configuration
logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(name)s: %(message)s")
logger = logging.getLogger("evrry.gateway")


@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("Initializing evrry AI Voice Gateway...")
    logger.info(f"Loaded 4 Voice Personas: {[p.name for p in get_all_personas()]}")
    yield
    logger.info("Shutting down evrry AI Voice Gateway...")


app = FastAPI(
    title="evrry AI Voice Gateway",
    description="Low-latency real-time voice concierge supporting 4 personas (Eli, Rony, Jenny, Sol)",
    version="1.0.0",
    lifespan=lifespan
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


class RoomTokenRequest(BaseModel):
    user_id: Optional[str] = None
    room_name: Optional[str] = None
    persona: Optional[str] = "eli"


class RoomTokenResponse(BaseModel):
    success: bool
    room_name: str
    token: str
    livekit_url: str
    persona: VoicePersona


@app.get("/health")
def health_check():
    return {
        "status": "healthy",
        "service": "ai-voice-gateway",
        "personas_count": len(get_all_personas()),
        "sample_rate": 16000,
        "supported_engines": ["faster-whisper", "ai4bharat-transliteration", "piper-tts", "livekit-webrtc"]
    }


@app.get("/personas", response_model=List[VoicePersona])
def list_personas():
    """Retrieve all 4 Persona Voice Agents."""
    return get_all_personas()


@app.get("/personas/{persona_id}", response_model=VoicePersona)
def get_single_persona(persona_id: str):
    """Retrieve details for a specific persona (eli, rony, jenny, sol)."""
    return get_persona(persona_id)


@app.post("/token", response_model=RoomTokenResponse)
def create_room_token(req: RoomTokenRequest):
    """Generate LiveKit WebRTC access token for voice conversation."""
    persona = get_persona(req.persona)
    uid = req.user_id or "guest"
    room = req.room_name or f"evrry-voice-{uid}-{persona.id}"

    livekit_url = os.getenv("LIVEKIT_URL", "ws://localhost:7880")
    livekit_key = os.getenv("LIVEKIT_API_KEY", "devkey")
    livekit_secret = os.getenv("LIVEKIT_API_SECRET", "secret")

    # Generate token (LiveKit SDK or mock)
    try:
        from livekit import api
        token = api.AccessToken(livekit_key, livekit_secret) \
            .with_identity(f"user-{uid}") \
            .with_name(f"Participant ({uid})") \
            .with_grants(api.VideoGrants(room_join=True, room=room)) \
            .to_jwt()
    except Exception:
        token = f"token-{persona.id}-{room}-dev"

    return RoomTokenResponse(
        success=True,
        room_name=room,
        token=token,
        livekit_url=livekit_url,
        persona=persona
    )


@app.websocket("/ws/voice-agent")
async def voice_agent_websocket(
    websocket: WebSocket,
    persona: str = Query("eli"),
    user_id: Optional[str] = Query(None)
):
    """
    Direct full-duplex WebSocket for 16kHz audio streaming.
    Receives:
      - Binary: 16kHz 16-bit mono raw PCM audio bytes
      - Text: JSON commands (e.g. {"action": "SWITCH_PERSONA", "persona": "sol"})
    Sends:
      - Binary: Synthesized PCM audio from assistant
      - Text: JSON events (TRANSCRIPTION, AI_REPLY, UI_ACTION)
    """
    await websocket.accept()
    pipeline = VoicePipeline(persona_id=persona)
    active_persona = pipeline.persona

    logger.info(f"WebSocket client connected. User: {user_id}, Persona: {active_persona.name}")

    # Send initial greeting event
    await websocket.send_text(json.dumps({
        "type": "SESSION_STARTED",
        "persona": active_persona.id,
        "persona_name": active_persona.name,
        "greeting": active_persona.sample_greeting
    }))

    try:
        while True:
            message = await websocket.receive()

            # Handle text control messages
            if "text" in message:
                try:
                    data = json.loads(message["text"])
                    if data.get("action") == "SWITCH_PERSONA":
                        new_persona_id = data.get("persona", "eli")
                        pipeline.set_persona(new_persona_id)
                        await websocket.send_text(json.dumps({
                            "type": "PERSONA_SWITCHED",
                            "persona": pipeline.persona.id,
                            "persona_name": pipeline.persona.name
                        }))
                except Exception as e:
                    logger.warning(f"Invalid text message: {e}")

            # Handle binary audio chunks
            elif "bytes" in message:
                chunk = message["bytes"]
                pipeline.push_audio_chunk(chunk)

                # Check if user has stopped speaking
                if pipeline.is_turn_complete():
                    await websocket.send_text(json.dumps({"type": "PROCESSING_TURN"}))
                    result = await pipeline.process_turn()

                    if result:
                        # 1. Send textual transcription and reply
                        await websocket.send_text(json.dumps({
                            "type": "TURN_RESULT",
                            "user_text": result["user_text"],
                            "devanagari_text": result["devanagari_text"],
                            "reply": result["assistant_reply"],
                            "persona": result["persona"],
                            "ui_actions": result.get("ui_actions", [])
                        }))

                        # 2. Stream audio response bytes
                        pcm_audio = result.get("pcm_audio")
                        if pcm_audio:
                            # Stream in 100ms chunks (3200 bytes per chunk at 16kHz 16-bit)
                            chunk_size = 3200
                            for i in range(0, len(pcm_audio), chunk_size):
                                if pipeline._is_interrupted:
                                    logger.info("Streaming interrupted by user barge-in.")
                                    break
                                await websocket.send_bytes(pcm_audio[i:i + chunk_size])

    except WebSocketDisconnect:
        logger.info(f"WebSocket client disconnected ({user_id})")
    except Exception as e:
        logger.error(f"WebSocket error: {e}")


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
