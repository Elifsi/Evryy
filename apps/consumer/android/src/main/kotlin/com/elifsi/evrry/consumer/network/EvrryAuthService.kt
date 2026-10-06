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
 * Implements WhatsApp OTP Authentication (primary) with Domestic SMS Fallback.
 * In development, operates in Mock Mode (zero cost).
 */

@Serializable
data class SendOtpRequest(
    val phone: String,
    val channel: String = "whatsapp",
    val otp: String? = null,
    val message: String? = null,
    val template: String? = null
)

@Serializable
data class SendOtpResponse(
    val success: Boolean,
    val channel: String? = "whatsapp",
    val provider: String? = null,
    val mock: Boolean? = false,
    val otp: String? = null,
    val error: String? = null,
    val message: String? = null,
    val retry_after_seconds: Int? = null
)

// Legacy alias for backward compatibility
typealias SendSmsRequest = SendOtpRequest
typealias SendSmsResponse = SendOtpResponse

@Singleton
class EvrryAuthService @Inject constructor(
    private val supabase: SupabaseClient
) {
    /**
     * Request a 6-digit WhatsApp OTP verification code for a Nepal mobile number.
     * Number format can be "+97798XXXXXXXX" or "98XXXXXXXX".
     */
    suspend fun requestWhatsAppOtp(phoneNumber: String): Result<SendOtpResponse> = runCatching {
        supabase.functions.invoke(
            function = "send-otp",
            body = SendOtpRequest(
                phone = normalizeNepalPhone(phoneNumber),
                channel = "whatsapp"
            )
        )
    }

    /**
     * Request OTP via specified channel ("whatsapp" or "sms").
     */
    suspend fun requestOtp(phoneNumber: String, channel: String = "whatsapp"): Result<SendOtpResponse> = runCatching {
        supabase.functions.invoke(
            function = "send-otp",
            body = SendOtpRequest(
                phone = normalizeNepalPhone(phoneNumber),
                channel = channel
            )
        )
    }

    /**
     * Request a 6-digit SMS OTP code for a Nepal mobile number via Supabase Auth.
     */
    suspend fun signInWithPhone(phoneNumber: String): Result<Unit> = runCatching {
        supabase.auth.signInWith(OTP) {
            phone = normalizeNepalPhone(phoneNumber)
        }
    }

    /**
     * Verify the 6-digit OTP code and establish authenticated session.
     */
    suspend fun verifyPhoneOtp(phoneNumber: String, token: String): Result<Unit> = runCatching {
        supabase.auth.verifyPhoneOtp(
            type = io.github.jan.supabase.auth.OtpType.Phone.SMS,
            phone = normalizeNepalPhone(phoneNumber),
            token = token
        )
    }

    /**
     * Fallback to direct "send-sms" Edge Function for testing / mock SMS.
     */
    suspend fun requestDirectSms(phoneNumber: String): Result<SendOtpResponse> = runCatching {
        supabase.functions.invoke(
            function = "send-sms",
            body = SendOtpRequest(
                phone = normalizeNepalPhone(phoneNumber),
                channel = "sms"
            )
        )
    }

    /**
     * Normalizes Nepal mobile numbers to standard E.164 (+97798XXXXXXXX).
     */
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
