package com.elifsi.evrry.partner.network

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.functions.functions
import kotlinx.serialization.Serializable
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Evrry Email Service (Partner Android)
 * Elifsi Technologies Private Limited
 *
 * Invokes server-side Supabase Edge Functions for partner email communications.
 * No private email API keys are stored in this application.
 */

@Serializable
data class SendPartnerKycRequest(
    val action: String = "partner_kyc_status",
    val to: String,
    val kycData: PartnerKycPayload
)

@Serializable
data class PartnerKycPayload(
    val tradeName: String,
    val status: String, // "approved" or "rejected"
    val rejectionReason: String? = null
)

@Serializable
data class SendPayoutStatementRequest(
    val action: String = "payout_statement",
    val to: String,
    val payoutData: PayoutStatementPayload
)

@Serializable
data class PayoutStatementPayload(
    val tradeName: String,
    val settlementDate: String,
    val netNpr: Double,
    val bankRef: String,
    val bankName: String? = null,
    val accountNumberMasked: String? = null
)

@Serializable
data class SendOtpRequest(
    val action: String = "verification_otp",
    val to: String,
    val otpData: OtpDataPayload
)

@Serializable
data class OtpDataPayload(
    val recipientName: String? = null,
    val otpCode: String,
    val validMinutes: Int = 10,
    val purpose: String? = null
)

@Serializable
data class EmailResponse(
    val success: Boolean,
    val id: String? = null,
    val error: String? = null,
    val mock: Boolean? = false
)

@Singleton
class EvrryPartnerEmailService @Inject constructor(
    private val supabase: SupabaseClient
) {
    /**
     * Dispatch partner email verification OTP.
     */
    suspend fun sendVerificationOtp(
        toEmail: String,
        otpCode: String,
        tradeName: String? = null
    ): Result<EmailResponse> = runCatching {
        supabase.functions.invoke(
            function = "send-email",
            body = SendOtpRequest(
                to = toEmail,
                otpData = OtpDataPayload(
                    recipientName = tradeName,
                    otpCode = otpCode,
                    purpose = "verify your merchant account and access the partner dashboard"
                )
            )
        )
    }

    /**
     * Request partner KYC status email (typically called by admin or system).
     */
    suspend fun notifyKycStatus(
        toEmail: String,
        tradeName: String,
        isApproved: Boolean,
        rejectionReason: String? = null
    ): Result<EmailResponse> = runCatching {
        supabase.functions.invoke(
            function = "send-email",
            body = SendPartnerKycRequest(
                to = toEmail,
                kycData = PartnerKycPayload(
                    tradeName = tradeName,
                    status = if (isApproved) "approved" else "rejected",
                    rejectionReason = rejectionReason
                )
            )
        )
    }
}
