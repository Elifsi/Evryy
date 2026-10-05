package com.elifsi.evrry.consumer.network

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.functions.functions
import kotlinx.serialization.Serializable
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Evrry Email Service (Consumer Android)
 * Elifsi Technologies Private Limited
 *
 * Dispatches email notifications securely through Supabase Edge Functions.
 * NOTE: Android clients NEVER store RESEND_API_KEY. All email logic is
 * executed server-side via the "send-email" Edge Function.
 */

@Serializable
data class SendInvoiceRequest(
    val action: String = "order_invoice",
    val to: String,
    val invoiceData: InvoiceDataPayload
)

@Serializable
data class InvoiceDataPayload(
    val orderNo: String,
    val placedAt: String,
    val customerName: String,
    val customerEmail: String,
    val customerPhone: String? = null,
    val deliveryAddress: String? = null,
    val merchantName: String,
    val merchantAddress: String? = null,
    val merchantPan: String? = null,
    val paymentMethod: String,
    val items: List<InvoiceLineItemPayload>,
    val subtotalPaisa: Long,
    val deliveryFeePaisa: Long,
    val platformFeePaisa: Long,
    val taxPaisa: Long,
    val discountPaisa: Long? = 0,
    val totalPaisa: Long
)

@Serializable
data class InvoiceLineItemPayload(
    val name: String,
    val quantity: Int,
    val unitPricePaisa: Long,
    val packagingUnit: String? = null,
    val itemNote: String? = null
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
data class SendEmailResponse(
    val success: Boolean,
    val id: String? = null,
    val error: String? = null,
    val mock: Boolean? = false
)

@Singleton
class EvrryEmailService @Inject constructor(
    private val supabase: SupabaseClient
) {
    /**
     * Request an order invoice email to be dispatched to the customer.
     */
    suspend fun sendOrderInvoice(
        customerEmail: String,
        invoiceData: InvoiceDataPayload
    ): Result<SendEmailResponse> = runCatching {
        supabase.functions.invoke(
            function = "send-email",
            body = SendInvoiceRequest(to = customerEmail, invoiceData = invoiceData)
        )
    }

    /**
     * Request email 6-digit OTP verification code.
     */
    suspend fun sendVerificationOtp(
        toEmail: String,
        otpCode: String,
        recipientName: String? = null,
        purpose: String? = "verify your email address"
    ): Result<SendEmailResponse> = runCatching {
        supabase.functions.invoke(
            function = "send-email",
            body = SendOtpRequest(
                to = toEmail,
                otpData = OtpDataPayload(
                    recipientName = recipientName,
                    otpCode = otpCode,
                    purpose = purpose
                )
            )
        )
    }
}
