package com.elifsi.evrry.consumer.network

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.functions.functions
import kotlinx.serialization.Serializable
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Evrry Payment Service (Consumer Android)
 * Elifsi Technologies Private Limited
 *
 * Initiates and verifies direct payment rails (eSewa, Khalti, Fonepay QR).
 * Zero merchant secret keys or private HMAC tokens embedded in the Android binary.
 */

@Serializable
data class PaymentInitiateRequest(
    val reference_type: String = "order",
    val reference_id: String,
    val method: String, // "esewa" | "khalti" | "fonepay_qr"
    val return_url: String? = null
)

@Serializable
data class EsewaFormParams(
    val amount: String,
    val tax_amount: String,
    val total_amount: String,
    val transaction_uuid: String,
    val product_code: String,
    val product_service_charge: String,
    val product_delivery_charge: String,
    val success_url: String,
    val failure_url: String,
    val signed_field_names: String,
    val signature: String
)

@Serializable
data class PaymentInitiateResponse(
    val success: Boolean,
    val provider: String,
    val is_sandbox: Boolean? = true,
    // eSewa specific
    val gateway_url: String? = null,
    val form_params: EsewaFormParams? = null,
    // Khalti specific
    val pidx: String? = null,
    val payment_url: String? = null,
    val expires_at: String? = null,
    // Fonepay specific
    val qr_string: String? = null,
    val prn: String? = null,
    val amount_npr: String? = null,
    // Error handling
    val error: String? = null
)

@Serializable
data class PaymentVerifyRequest(
    val provider: String,
    val reference_type: String = "order",
    val reference_id: String,
    val pidx: String? = null,
    val data: String? = null,
    val transaction_uuid: String? = null,
    val prn: String? = null
)

@Serializable
data class PaymentVerifyResponse(
    val success: Boolean,
    val payment_id: String? = null,
    val reference_id: String? = null,
    val provider: String? = null,
    val transaction_ref: String? = null,
    val amount_paisa: Long? = null,
    val status: String? = null,
    val error: String? = null,
    val message: String? = null
)

@Singleton
class EvrryPaymentService @Inject constructor(
    private val supabase: SupabaseClient
) {
    /**
     * Request gateway payment session (eSewa HMAC, Khalti pidx, or Fonepay QR).
     */
    suspend fun initiatePayment(
        orderId: String,
        method: String,
        returnUrl: String? = null
    ): Result<PaymentInitiateResponse> = runCatching {
        supabase.functions.invoke(
            function = "payment-initiate",
            body = PaymentInitiateRequest(
                reference_type = "order",
                reference_id = orderId,
                method = method,
                return_url = returnUrl
            )
        )
    }

    /**
     * Confirm payment after gateway checkout completion.
     */
    suspend fun verifyPayment(
        orderId: String,
        provider: String,
        pidx: String? = null,
        esewaData: String? = null,
        transactionUuid: String? = null,
        prn: String? = null
    ): Result<PaymentVerifyResponse> = runCatching {
        supabase.functions.invoke(
            function = "payment-verify",
            body = PaymentVerifyRequest(
                provider = provider,
                reference_type = "order",
                reference_id = orderId,
                pidx = pidx,
                data = esewaData,
                transaction_uuid = transactionUuid,
                prn = prn
            )
        )
    }
}
