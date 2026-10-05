package com.elifsi.evrry.partner.network

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.postgrest
import io.github.jan.supabase.postgrest.rpc
import kotlinx.serialization.Serializable
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Evrry Partner Push Service (Partner Android)
 * Elifsi Technologies Private Limited
 *
 * Registers partner device tokens with `partner_id` to wake up kitchen
 * displays (KDS), driver phones, and store terminals.
 */

@Serializable
data class PartnerRegisterTokenParams(
    val p_token: String,
    val p_platform: String = "android",
    val p_app_variant: String = "partner",
    val p_device_model: String? = null,
    val p_partner_id: String? = null
)

@Serializable
data class PartnerUnregisterTokenParams(
    val p_token: String
)

@Singleton
class EvrryPartnerPushService @Inject constructor(
    private val supabase: SupabaseClient
) {
    /**
     * Register partner device token (binds to active restaurant/store/driver).
     */
    suspend fun registerDeviceToken(
        fcmToken: String,
        partnerId: String,
        deviceModel: String = android.os.Build.MODEL
    ): Result<String> = runCatching {
        supabase.postgrest.rpc(
            function = "register_device_token",
            parameters = PartnerRegisterTokenParams(
                p_token = fcmToken,
                p_platform = "android",
                p_app_variant = "partner",
                p_device_model = deviceModel,
                p_partner_id = partnerId
            )
        ).decodeAs<String>()
    }

    /**
     * Deactivate token upon partner logout.
     */
    suspend fun unregisterDeviceToken(fcmToken: String): Result<Unit> = runCatching {
        supabase.postgrest.rpc(
            function = "unregister_device_token",
            parameters = PartnerUnregisterTokenParams(p_token = fcmToken)
        )
    }
}
