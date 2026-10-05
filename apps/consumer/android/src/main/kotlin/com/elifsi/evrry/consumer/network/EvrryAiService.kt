package com.elifsi.evrry.consumer.network

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.functions.functions
import kotlinx.serialization.Serializable
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Evrry AI Concierge Service (Consumer Android)
 * Elifsi Technologies Private Limited
 *
 * Dispatches natural language voice commands to server-side AI Gateway.
 * Zero OpenRouter or Gemini keys embedded in Android binary.
 */

@Serializable
data class VoiceChatRequest(
    val action: String = "voice_concierge",
    val prompt: String,
    val user_id: String? = null
)

@Serializable
data class VoiceChatResponse(
    val success: Boolean,
    val action: String? = null,
    val reply: String,
    val mock: Boolean? = false,
    val user_context_injected: Boolean? = false,
    val error: String? = null
)

@Singleton
class EvrryAiService @Inject constructor(
    private val supabase: SupabaseClient
) {
    /**
     * Send transcribed voice text to the AI Concierge.
     */
    suspend fun chatWithConcierge(
        userText: String,
        userId: String? = null
    ): Result<VoiceChatResponse> = runCatching {
        supabase.functions.invoke(
            function = "ai-gateway",
            body = VoiceChatRequest(
                prompt = userText,
                user_id = userId
            )
        )
    }
}
