package com.elifsi.evrry.partner.network

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.functions.functions
import kotlinx.serialization.Serializable
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Evrry Partner AI Co-Pilot Service (Partner Android)
 * Elifsi Technologies Private Limited
 *
 * Implements:
 * 1. Photo-to-Menu Vision OCR (scans paper menus into draft catalog).
 * 2. Kitchen Voice Out-of-Stock Toggle ("Chicken momo sakiyo").
 */

@Serializable
data class PhotoToMenuRequest(
    val action: String = "photo_to_menu",
    val image_base64: String? = null,
    val image_url: String? = null
)

@Serializable
data class DraftCatalogItem(
    val name: String,
    val price_npr: Double,
    val category: String,
    val description: String? = null
)

@Serializable
data class PhotoToMenuResponse(
    val success: Boolean,
    val items_extracted_count: Int? = 0,
    val draft_catalog_items: List<DraftCatalogItem>? = emptyList(),
    val error: String? = null
)

@Serializable
data class KitchenVoiceRequest(
    val action: String = "kitchen_voice",
    val prompt: String,
    val partner_id: String
)

@Serializable
data class KitchenVoiceResponse(
    val success: Boolean,
    val item_name: String? = null,
    val is_available: Boolean? = false,
    val confirmation_voice_reply: String? = null,
    val error: String? = null
)

@Singleton
class EvrryPartnerAiService @Inject constructor(
    private val supabase: SupabaseClient
) {
    /**
     * Scan paper menu photo to generate draft catalog items for partner approval.
     */
    suspend fun parseMenuPhoto(imageBase64: String): Result<PhotoToMenuResponse> = runCatching {
        supabase.functions.invoke(
            function = "ai-gateway",
            body = PhotoToMenuRequest(image_base64 = imageBase64)
        )
    }

    /**
     * Execute chef voice out-of-stock command (e.g. "Chicken momo sakiyo").
     */
    suspend fun executeKitchenVoiceCommand(
        voicePhrase: String,
        partnerId: String
    ): Result<KitchenVoiceResponse> = runCatching {
        supabase.functions.invoke(
            function = "ai-gateway",
            body = KitchenVoiceRequest(prompt = voicePhrase, partner_id = partnerId)
        )
    }
}
