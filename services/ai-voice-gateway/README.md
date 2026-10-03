# AI Voice & Speech Gateway Service

> **Microservice**: `services/ai-voice-gateway`  
> **Platform**: evrry Super App Ecosystem  
> **Maintainer**: Elifsi Technologies Private Limited  
> **Protocols**: Bidirectional WebSockets (`/ws/voice-agent`), 16kHz PCM audio streaming, OpenAI Tool Calling schemas  

---

## 1. Overview & Architecture

The **AI Voice Gateway** is a high-performance Python asynchronous microservice powering the real-time, voice-first ordering and concierge experience in **evrry**. It handles bidirectional low-latency audio streams from mobile clients (Kotlin Android & Swift iOS), performs local automatic speech recognition (ASR), Romanized-to-Devanagari transliteration, tool-calling dialog orchestration via self-hosted open-weights LLMs (vLLM / Ollama), read-only Supabase queries, and local neural voice synthesis (TTS).

```
[ Mobile Client (Kotlin / Swift) ]
               │
               ▼  16kHz Raw PCM Bytes over WebSocket
┌─────────────────────────────────────────────────────────────┐
│                 AI VOICE GATEWAY (FastAPI)                  │
│                                                             │
│   1. Speech-to-Text (ASR)                                   │
│      ├── Faster-Whisper (16kHz in-memory PCM decoding)      │
│      └── AI4Bharat IndicConformer (Nepali 'ne', Hindi 'hi') │
│                                                             │
│   2. Transliteration Layer (ai4bharat-transliteration)      │
│      └── Romanized input ("momo pathaideu") → एक प्लेट मोमो │
│                                                             │
│   3. Agent Reasoning & Tool Loop (OpenAI client)            │
│      └── Local vLLM instance (Qwen/Qwen2.5-14B-Instruct)    │
│                                                             │
│   4. Catalog Query Execution (asyncpg)                      │
│      └── Read-only connection to Supabase PostgreSQL        │
│          (Role: `ai_agent_reader`)                          │
│                                                             │
│   5. Text-to-Speech (TTS)                                   │
│      ├── Piper-TTS (Nepali & Hindi .onnx checkpoints)       │
│      └── AI4Bharat Indic-Parler-TTS (expressive tone/gender)│
└─────────────────────────────────────────────────────────────┘
               │
               ▼  PCM Audio Stream + UI_ACTION JSON Events
[ Mobile Client (Kotlin / Swift) ]
```

---

## 2. Speech & Transliteration Stack

### A. Automatic Speech Recognition (ASR)
- **Faster-Whisper (`faster-whisper>=1.0.0`)**: Lightweight generalist processing 16kHz raw PCM bytes directly in GPU memory with continuous VAD (Voice Activity Detection).
- **AI4Bharat IndicConformer**: Native support for 22 scheduled regional languages, specifically tuned for Nepali (`ne`), Hindi (`hi`), and Maithili (`mai`). Handles local accents, code-switching, and rural background acoustic environments.

### B. Romanized Text Parsing (AI4Bharat IndicXlit)
- Users frequently speak or text in Romanized English (e.g. typing *"ek plate momo pathaideu"*).
- The `ai4bharat-transliteration` engine converts Romanized phonetic words directly into Devanagari script (एक प्लेट मोमो पठाइदेऊ) before executing database catalog lookups or prompting the LLM.

### C. Neural Speech Synthesis (TTS)
- **Piper-TTS (`piper-tts>=1.2.0`)**: Real-time neural voice engine running fast ONNX models on CPU/GPU.
- **AI4Bharat Indic-Parler-TTS (`parler-tts>=0.2.0`)**: High-fidelity open-weight neural TTS supporting prompt-based tone, gender, and pacing control (e.g., *"Aditi speaks in an expressive, cheerful tone at a normal pace"*).

---

## 3. End-to-End Voice Ordering Lifecycle

1. **Audio Capture**: Mobile app records audio via native hardware mic (AudioRecord in Android / AVAudioEngine in iOS) and streams 16kHz 16-bit mono PCM chunks over `wss://gateway.evrry.app/ws/voice-agent`.
2. **Streaming ASR**: Transcribed incrementally with low-latency streaming endpoints.
3. **Phonetic Normalization**: Transliterated into Devanagari if Romanized words are detected.
4. **Tool Execution**: The LLM calls schema tools such as:
   - `search_menu_items(query="momo", sort="rating_desc")`
   - `add_to_cart(dish_id="...", quantity=1)`
5. **Database Interaction**: Python executes fast parameterized read-only queries against Supabase using `asyncpg`.
6. **UI Action Dispatch**: The gateway pushes a `UI_ACTION` event over the WebSocket, causing the client app to update the bottom cart bar dynamically.
7. **Audio Playback**: The synthesized voice confirmation stream is pushed back to the client and played over the device speaker.

---

## 4. Dependencies

See [`requirements.txt`](./requirements.txt) for the complete pinned dependency specification.
