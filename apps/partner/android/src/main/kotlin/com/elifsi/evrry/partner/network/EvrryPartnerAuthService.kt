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
 * Facilitates merchant/rider/driver phone login via Nepal domestic SMS.
 */

@Serializable
data class PartnerSmsRequest(
    val phone: String,
    val otp: String? = null
)

@Serializable
data class PartnerSmsResponse(
    val success: Boolean,
    val provider: String? = null,
    val mock: Boolean? = false,
    val otp: String? = null,
    val error: String? = null,
    val retry_after_seconds: Int? = null
)

@Singleton
class EvrryPartnerAuthService @Inject constructor(
    private val supabase: SupabaseClient
) {
    /**
     * Request partner login OTP via domestic SMS.
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

    private fun normalizeNepalPhone(raw: String): String {
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
