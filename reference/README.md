# Reference Repositories

Third-party open-source repos kept **for reference only** (reading patterns, not vendored into evrry). Clones are gitignored; run `./sync.sh` to fetch/update them.

| Role | Repo | Stack | Why we care |
|---|---|---|---|
| Voice Agent (Server Engine) | [livekit/agents](https://github.com/livekit/agents) | Python / Node.js | Sub-200ms WebRTC agent pipeline with native function calling (`@function_tool`) that queries Supabase and pushes real-time screen events. |
| Voice Agent (Multimodal Alt) | [pipecat-ai/pipecat](https://github.com/pipecat-ai/pipecat) | Python | Production pipeline framework supporting Gemini Live and OpenAI Realtime with client starter kits. |
| Voice Client (Android) | [livekit/client-sdk-android](https://github.com/livekit/client-sdk-android) | Kotlin, WebRTC | Bi-directional audio streaming and real-time data channel packet consumption. |
| Voice Client (iOS) | [livekit/client-sdk-swift](https://github.com/livekit/client-sdk-swift) | Swift, SwiftUI | WebRTC audio capture, speaker playback, and UI synchronization channels. |
| Voice Client (Web) | [livekit/components-js](https://github.com/livekit/components-js) | Next.js, React | Pre-built React hooks (`useVoiceAssistant`, `useDataChannel`) for browser voice integration. |

Check each repo's license before copying any code into evrry.
