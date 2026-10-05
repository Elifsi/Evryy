# AI Voice Architecture: 4 Persona Agents & WebRTC Pipeline
**evrry Super App Platform**  
*Elifsi Technologies Private Limited*

---

## 1. Overview & System Objectives

The **evrry AI Voice Concierge** delivers an ultra-low latency (< 300ms round trip), voice-first ordering and conversational experience across all 5 core platform verticals (Food, Grocery, InDrive Cab/Bike Bidding, Stays/Hotels, and Rentals).

Rather than relying on a single generic synthetic voice, the platform provides **4 Persona Voice Agents** inspired by top voice models like ChatGPT Voice (e.g., Sol, Breeze, Cove):
1. **Eli** — Youthful, energetic, and quick-witted female concierge (flagship everyday guide).
2. **Rony** — Deep baritone, authoritative, and formal (executive concierge).
3. **Jenny** — Sweet, warm, cheerful, and hospitable (grocery & travel companion).
4. **Suka** — Mellow, soothing, calm, and thoughtful male concierge (evening & wellness assistant).

```mermaid
flowchart TD
    subgraph Mobile / Web Client
        A["Native Microphone (16kHz 16-bit PCM)"]
        B["LiveKit WebRTC Client / WebSocket Audio Track"]
    end

    subgraph LiveKit WebRTC SFU Server
        C["LiveKit Media Server (ws://livekit:7880)"]
    end

    subgraph AI Voice Gateway (Python Service)
        D["Voice Activity Detection (VAD) & Barge-In Handler"]
        E["Faster-Whisper (ASR) + IndicConformer"]
        F["AI4Bharat IndicXlit (Romanized to Devanagari)"]
        G["LLM Dialog Orchestrator (vLLM / OpenRouter)"]
        H["Tool Calling: search_catalog, add_to_cart, ride_fare"]
        I["Neural TTS (Piper-TTS / Indic-Parler-TTS)"]
        J["Persona Vocal Modulation (Pitch & Speed)"]
    end

    subgraph Database & Cloud
        K["Supabase PostgreSQL (Read-Only Replicas)"]
        L["User Context & Consent-Gated Memory (get_ai_context)"]
    end

    A --> B
    B <--> C
    C <--> D
    D --> E
    E --> F
    F --> G
    G <--> H
    H <--> K
    G <--> L
    G --> I
    I --> J
    J --> C
```

---

## 2. The 4 Persona Voice Agents

Each persona has distinct acoustic characteristics, pitch offsets, cadence speeds, and behavioral prompts:

| Persona | Gender | Timbre & Cadence | Pitch | Speed | Domain Specialties | Personality & Sample Greeting |
|---|---|---|---|---|---|---|
| **Eli** | Female | Bright Alto / Soprano, crisp, punchy | `+0.08` | `1.05x` | Food delivery, fast momo orders, quick motorbike rides, daily chores | *Youthful female Kathmandu guide.* Speaks colloquial Nepali and English ("Hajur", "Dai", "Mitho chha", "Ekdam fast").<br>`"Namaste! Eli here. Momo, grocery, ya bike ride — k chaiyo tapailai? Ekdam fast ready gardinchu!"` |
| **Rony** | Male | Deep Baritone, composed, formal | `-0.08` | `0.95x` | InDrive cab fare bidding, hotel room reservations, long-term rentals, corporate orders | *Executive concierge.* Authoritative, respectful, and decisive. Refined formal Nepali ("Namaskar", "Tapailai swaagat chha").<br>`"Namaskar. I am Rony, your executive concierge. Whether you need corporate transport, hotel suites, or ride fare coordination, I am at your service."` |
| **Jenny** | Female | Soprano / Bright Alto, melodic, warm | `+0.06` | `1.00x` | Supermarket groceries, fresh produce, family homestays, customer care | *Hospitable & cheerful companion.* Attentive and polite ("Namaste! Kasto chha tapailai?"). Highlights freshness and discount vouchers.<br>`"Namaste! I am Jenny! Kasto chha tapailai? Fresh fruits, kitchen groceries, ki family hotel khojdai hunuhunchha? Let me help you find the best options!"` |
| **Suka** | Male | Warm Baritone, soft, soothing, serene | `-0.05` | `0.92x` | Late-night comfort food, relaxing night rides home, step-by-step guidance, support | *Calm & thoughtful male assistant.* Soft-spoken, patient, unhurried, reassuring.<br>`"Namaste... I am Suka. Take a breath and relax. Tell me how you are feeling or what you need tonight, and we will take care of it together."` |

---

## 3. Speech & Language Processing Stack

### A. Speech-to-Text (ASR)
- **Faster-Whisper (`faster-whisper>=1.0.0`)**: Runs CTranslate2 inference directly on 16kHz PCM audio buffers. Features internal Voice Activity Detection (VAD) with `min_silence_duration_ms=400` for rapid end-of-utterance detection.
- **AI4Bharat IndicConformer**: Provides high-accuracy acoustic modeling for regional Nepali (`ne`), Hindi (`hi`), and Maithili (`mai`) dialects, effectively handling noisy street backgrounds and localized accents.

### B. Phonetic Transliteration (AI4Bharat IndicXlit)
- Nepali users frequently speak or type in Romanized script (e.g., *"ek plate momo pathaideu"* or *"baneshwor jane bike"*).
- The `ai4bharat-transliteration` engine automatically transliterates Romanized phonetics into Devanagari script (एक प्लेट मोमो पठाइदेऊ) before catalog search or LLM reasoning.

### C. Neural Speech Synthesis (TTS)
- **Piper-TTS (`piper-tts>=1.2.0`)**: Ultra-fast local neural ONNX synthesis (< 50ms time-to-first-sample) running on CPU/GPU.
- **AI4Bharat Indic-Parler-TTS (`parler-tts>=0.2.0`)**: High-fidelity regional voice synthesis providing authentic native Nepali pronunciation without Western robotic artifacts.
- **Dynamic Pitch & Speed Modulation**: Adjusts frequency harmonics and phoneme duration dynamically according to the active persona profile.

---

## 4. WebRTC (LiveKit) vs. WebSocket Dual-Mode Architecture

The platform supports two transport channels:

1. **LiveKit WebRTC (`ws://livekit:7880`) [Production Mobile & Web]**:
   - Ultra-low latency full-duplex audio room.
   - Built-in echo cancellation, noise suppression, and adaptive bitrate.
   - Server mints short-lived room tokens via `supabase/functions/ai-gateway/` (`create_voice_room`).
   - Pushes `UI_ACTION` events (e.g. `ADD_TO_CART`, `SHOW_RIDE_ESTIMATE`) over the LiveKit Data Channel.
2. **Direct Audio WebSocket (`/ws/voice-agent`) [Lightweight Dev & Fallback]**:
   - Direct full-duplex binary stream of 16kHz 16-bit mono PCM chunks.
   - No external media server required for local testing or low-resource devices.

---

## 5. Barge-in & Interruption Mechanics

To make voice conversations feel completely natural:
- The `VoicePipeline` monitors incoming microphone energy during assistant playback.
- If energy exceeds the speech threshold (`energy > 400`), a **barge-in event** triggers immediately.
- The gateway instantly:
  1. Sets `_is_interrupted = True`.
  2. Stops streaming remaining audio chunks to the client.
  3. Clears downstream audio playback queues.
  4. Resets the input buffer to ingest the new user utterance without delay.

---

## 6. Database Schema & User Preference Persistence

Implemented in Migration `20261005000017_ai_voice_personas.sql`:
- **ENUM `public.ai_voice_persona_enum`**: `'eli'`, `'rony'`, `'jenny'`, `'suka'`.
- **Table `public.ai_voice_personas`**: Catalog of active personas, system prompts, pitch/speed parameters, and TTS voice codes.
- **User Preference in `public.user_ai_profile`**:
  - `preferred_voice_persona`: Defaults to `'eli'`.
  - `voice_speed`: User-customizable speaking rate (`0.75x` to `1.50x`).
- **RPC `public.set_preferred_voice_persona(p_persona, p_speed)`**: Allows users to switch voices seamlessly in mobile/web settings.
- **Context Integration in `public.get_ai_context(p_user)`**: Returns the user's active persona and prompt instructions during session initialization.

---

## 7. Multiplatform Client Bridges

| Platform | Client Service | Key Voice Methods |
|---|---|---|
| **Android (Kotlin)** | [`apps/consumer/android/.../EvrryAiService.kt`](file:///home/rahul/codes/Evrry/apps/consumer/android/src/main/kotlin/com/elifsi/evrry/consumer/network/EvrryAiService.kt) | `createVoiceRoom(persona)`, `chatWithConcierge(prompt, persona)`, `setPreferredPersona(persona)` |
| **iOS (Swift)** | [`apps/consumer/ios/.../EvrryAiService.swift`](file:///home/rahul/codes/Evrry/apps/consumer/ios/EvrryConsumer/Services/EvrryAiService.swift) | `createVoiceRoom(persona)`, `chatWithConcierge(prompt, persona)`, `setPreferredPersona(persona)` |
| **Web (Next.js / TS)** | [`apps/web/common/ai.ts`](file:///home/rahul/codes/Evrry/apps/web/common/ai.ts) | `createVoiceRoom(persona)`, `chatWithConcierge(prompt, persona)`, `getPersonas()`, `setPreferredPersona(persona)` |
| **Prototype Phone (TS)** | [`prototype/Phone/lib/ai/personas.ts`](file:///home/rahul/codes/Evrry/prototype/Phone/lib/ai/personas.ts) | `getVoicePersona(id)`, `getAllVoicePersonas()` |
