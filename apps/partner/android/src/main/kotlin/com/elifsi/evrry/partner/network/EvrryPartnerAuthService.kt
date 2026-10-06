package com.elifsi.evrry.partner.network

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.auth.providers.builtin.OTP
import io.github.jan.supabase.functions.functions
import kotlinx.serialization.Serializable
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Evrry Partner Auth Service (Partner Android)
 * Elifsi Technologies Private Limited
 *
 * Facilitates merchant/rider/driver phone login via WhatsApp OTP (primary) with Domestic SMS fallback.
 */

@Serializable
data class PartnerOtpRequest(
    val phone: String,
    val channel: String = "whatsapp",
    val otp: String? = null,
    val message: String? = null,
    val template: String? = null
)

@Serializable
data class PartnerOtpResponse(
    val success: Boolean,
    val channel: String? = "whatsapp",
    val provider: String? = null,
    val mock: Boolean? = false,
    val otp: String? = null,
    val error: String? = null,
    val message: String? = null,
    val retry_after_seconds: Int? = null
)

// Backward compatibility alias
typealias PartnerSmsRequest = PartnerOtpRequest
typealias PartnerSmsResponse = PartnerOtpResponse

@Singleton
class EvrryPartnerAuthService @Inject constructor(
    private val supabase: SupabaseClient
) {
    /**
     * Request partner login OTP via WhatsApp Cloud API.
     */
    suspend fun requestWhatsAppOtp(phoneNumber: String): Result<PartnerOtpResponse> = runCatching {
        supabase.functions.invoke(
            function = "send-otp",
            body = PartnerOtpRequest(
                phone = normalizeNepalPhone(phoneNumber),
                channel = "whatsapp"
            )
        )
    }

    /**
     * Request partner login OTP via domestic SMS or WhatsApp channel.
     */
    suspend fun requestOtp(phoneNumber: String, channel: String = "whatsapp"): Result<PartnerOtpResponse> = runCatching {
        supabase.functions.invoke(
            function = "send-otp",
            body = PartnerOtpRequest(
                phone = normalizeNepalPhone(phoneNumber),
                channel = channel
            )
        )
    }

    /**
     * Request partner login OTP via Supabase Auth SMS channel.
     */
    suspend fun signInWithPhone(phoneNumber: String): Result<Unit> = runCatching {
        supabase.auth.signInWith(OTP) {
            phone = normalizeNepalPhone(phoneNumber)
        }
    }

    /**
     * Verify OTP and open partner dashboard session.
     */
    suspend fun verifyPhoneOtp(phoneNumber: String, token: String): Result<Unit> = runCatching {
        supabase.auth.verifyPhoneOtp(
            type = io.github.jan.supabase.auth.OtpType.Phone.SMS,
            phone = normalizeNepalPhone(phoneNumber),
            token = token
        )
    }

    fun normalizeNepalPhone(raw: String): String {
        val digitsOnly = raw.replace(Regex("[^0-9]"), "")
        return if (digitsOnly.startsWith("977")) {
            "+$digitsOnly"
        } else if (digitsOnly.length == 10) {
            "+977$digitsOnly"
        } else {
            raw
        }
    }
}
