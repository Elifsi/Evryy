# evryy Backend Microservices

> **Platform**: evryy Super App Ecosystem  
> **Company**: Elifsi Technologies Private Limited  

This directory contains standalone, specialized background services and gateway microservices complementing the centralized Supabase PostgreSQL database:

```
services/
├── ai-voice-gateway/           # Real-time WebSocket audio gateway (FastAPI, Faster-Whisper, AI4Bharat, Piper)
└── notification-worker/        # FCM/APNs push notification dispatcher & Celery queue worker
```

---

## 1. Services Summary

| Service | Technology | Primary Function | Primary Protocols |
|---|---|---|---|
| [`ai-voice-gateway`](./ai-voice-gateway/) | FastAPI, Python 3.11+, PyTorch | Streaming 16kHz PCM audio STT, transliteration, tool calling, neural TTS | WebSocket (`wss://`), HTTP/2 |
| [`notification-worker`](./notification-worker/) | Python, Celery, Redis, Firebase Admin | Push notification dispatch (FCM/APNs), background alerts, safety pings | Redis Queue, Supabase Webhooks |

---

## 2. Docker & Infrastructure Integration

All microservices run in containers coordinated via the root `docker-compose.yml`, which also spins up:
- **Redis**: Live driver coordinates (`GEOADD`), socket state, and push notification task queue.
- **OSRM Engine**: High-performance local routing and polyline engine using `nepal-latest.osm.pbf`.
- **vLLM / Ollama**: Local open-weights LLM server hosting Qwen 2.5.
- **Caddy / Nginx**: Reverse proxy with automatic SSL and WebSocket proxying.
