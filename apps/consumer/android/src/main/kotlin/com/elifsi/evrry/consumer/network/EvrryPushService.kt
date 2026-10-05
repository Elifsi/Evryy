package com.elifsi.evrry.consumer.network

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.postgrest
import io.github.jan.supabase.postgrest.rpc
import kotlinx.serialization.Serializable
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Evrry Push Notification Service (Consumer Android)
 * Elifsi Technologies Private Limited
 *
 * Registers FCM device tokens with the central database to receive
 * real-time order updates, driver arrivals, and chat alerts.
 */

@Serializable
data class RegisterTokenParams(
    val p_token: String,
    val p_platform: String = "android",
    val p_app_variant: String = "consumer",
    val p_device_model: String? = null,
    val p_partner_id: String? = null
)

@Serializable
data class UnregisterTokenParams(
    val p_token: String
)

@Singleton
class EvrryPushService @Inject constructor(
    private val supabase: SupabaseClient
) {
    /**
     * Register or refresh Android FCM registration token.
     */
    suspend fun registerDeviceToken(
        fcmToken: String,
        deviceModel: String = android.os.Build.MODEL
    ): Result<String> = runCatching {
        supabase.postgrest.rpc(
            function = "register_device_token",
            parameters = RegisterTokenParams(
                p_token = fcmToken,
                p_platform = "android",
                p_app_variant = "consumer",
                p_device_model = deviceModel
            )
        ).decodeAs<String>()
    }

    /**
     * Deactivate token upon user logout.
     */
    suspend fun unregisterDeviceToken(fcmToken: String): Result<Unit> = runCatching {
        supabase.postgrest.rpc(
            function = "unregister_device_token",
            parameters = UnregisterTokenParams(p_token = fcmToken)
        )
    }
}
