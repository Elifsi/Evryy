package com.elifsi.evrry.consumer.network

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.auth.providers.builtin.OTP
import io.github.jan.supabase.functions.functions
import kotlinx.serialization.Serializable
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Evrry Authentication Service (Consumer Android)
 * Elifsi Technologies Private Limited
 *
 * Implements Phone SMS OTP Authentication with Nepal mobile carriers (NTC/Ncell).
 * In development, operates in Mock Mode (zero SMS cost).
 */

@Serializable
data class SendSmsRequest(
    val phone: String,
    val otp: String? = null,
    val message: String? = null
)

@Serializable
data class SendSmsResponse(
    val success: Boolean,
    val provider: String? = null,
    val mock: Boolean? = false,
    val otp: String? = null,
    val error: String? = null,
    val retry_after_seconds: Int? = null
)

@Singleton
class EvrryAuthService @Inject constructor(
    private val supabase: SupabaseClient
) {
    /**
     * Request a 6-digit SMS OTP code for a Nepal mobile number.
     * Number format can be "+97798XXXXXXXX" or "98XXXXXXXX".
     */
    suspend fun signInWithPhone(phoneNumber: String): Result<Unit> = runCatching {
        supabase.auth.signInWith(OTP) {
            phone = normalizeNepalPhone(phoneNumber)
        }
    }

    /**
     * Verify the 6-digit SMS OTP code and establish authenticated session.
     */
    suspend fun verifyPhoneOtp(phoneNumber: String, token: String): Result<Unit> = runCatching {
        supabase.auth.verifyPhoneOtp(
            type = io.github.jan.supabase.auth.OtpType.Phone.SMS,
            phone = normalizeNepalPhone(phoneNumber),
            token = token
        )
    }

    /**
     * Direct fallback to "send-sms" Edge Function for testing / mock OTP.
     */
    suspend fun requestDirectSms(phoneNumber: String): Result<SendSmsResponse> = runCatching {
        supabase.functions.invoke(
            function = "send-sms",
            body = SendSmsRequest(phone = normalizeNepalPhone(phoneNumber))
        )
    }

    /**
     * Normalizes Nepal mobile numbers to standard E.164 (+97798XXXXXXXX).
     */
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
