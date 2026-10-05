package com.elifsi.evrry.consumer.network

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.functions.functions
import io.github.jan.supabase.postgrest.postgrest
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Evrry AI Concierge & Real-Time Voice Service (Consumer Android)
 * Elifsi Technologies Private Limited
 *
 * Supports:
 * - 4 Voice Personas: Eli (Youthful/Energetic), Rony (Deep/Executive), Jenny (Sweet/Hospitable), Sol (Calm/Soothing)
 * - LiveKit WebRTC room token acquisition for real-time voice streaming
 * - Natural language AI concierge text chat with memory context injection
 * - Zero secrets embedded in mobile binary
 */

@Serializable
enum class VoicePersona {
    @SerialName("eli") ELI,
    @SerialName("rony") RONY,
    @SerialName("jenny") JENNY,
    @SerialName("sol") SOL
}

@Serializable
data class VoicePersonaMeta(
    val id: String,
    val name: String,
    val gender: String,
    val tagline: String,
    val tone: String,
    val tts_voice_code: String? = null,
    val pitch: Double? = 0.0,
    val speed: Double? = 1.0,
    val sample_greeting: String? = null
)

@Serializable
data class VoiceChatRequest(
    val action: String = "voice_concierge",
    val prompt: String,
    val user_id: String? = null,
    val persona: String? = "eli"
)

@Serializable
data class VoiceChatResponse(
    val success: Boolean,
    val action: String? = null,
    val reply: String,
    val persona: String? = "eli",
    val persona_name: String? = null,
    val mock: Boolean? = false,
    val user_context_injected: Boolean? = false,
    val error: String? = null
)

@Serializable
data class VoiceRoomRequest(
    val action: String = "create_voice_room",
    val persona: String = "eli",
    val user_id: String? = null,
    val room_name: String? = null
)

@Serializable
data class VoiceRoomResponse(
    val success: Boolean,
    val room_name: String,
    val server_url: String,
    val token: String,
    val persona: VoicePersonaMeta,
    val websocket_fallback_url: String? = null,
    val is_mock: Boolean? = false,
    val error: String? = null
)

@Serializable
data class SetPersonaRpcParams(
    val p_persona: String,
    val p_speed: Double = 1.00
)

@Singleton
class EvrryAiService @Inject constructor(
    private val supabase: SupabaseClient
) {
    /**
     * Send transcribed voice text to the AI Concierge with chosen persona.
     */
    suspend fun chatWithConcierge(
        userText: String,
        persona: VoicePersona = VoicePersona.ELI,
        userId: String? = null
    ): Result<VoiceChatResponse> = runCatching {
        supabase.functions.invoke(
            function = "ai-gateway",
            body = VoiceChatRequest(
                prompt = userText,
                user_id = userId,
                persona = persona.name.lowercase()
            )
        )
    }

    /**
     * Create a low-latency WebRTC audio room with the selected Persona Voice Agent.
     */
    suspend fun createVoiceRoom(
        persona: VoicePersona = VoicePersona.ELI,
        userId: String? = null
    ): Result<VoiceRoomResponse> = runCatching {
        supabase.functions.invoke(
            function = "ai-gateway",
            body = VoiceRoomRequest(
                persona = persona.name.lowercase(),
                user_id = userId
            )
        )
    }

    /**
     * Persist user's preferred voice persona in database.
     */
    suspend fun setPreferredPersona(
        persona: VoicePersona,
        speed: Double = 1.00
    ): Result<Unit> = runCatching {
        supabase.postgrest.rpc(
            function = "set_preferred_voice_persona",
            parameters = SetPersonaRpcParams(
                p_persona = persona.name.lowercase(),
                p_speed = speed
            )
        )
    }
}
