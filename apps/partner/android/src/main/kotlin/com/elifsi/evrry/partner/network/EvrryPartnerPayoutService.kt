package com.elifsi.evrry.partner.network

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.functions.functions
import kotlinx.serialization.Serializable
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Evrry Partner Payout Service (Partner Android)
 * Elifsi Technologies Private Limited
 *
 * Implements On-Demand Instant Cash Out (Bank / eSewa / Khalti)
 * and view historical settlement statements.
 */

@Serializable
data class OnDemandPayoutRequest(
    val action: String = "on_demand_payout",
    val partner_id: String,
    val amount_paisa: Long,
    val destination_type: String = "bank", // "bank" | "esewa" | "khalti"
    val wallet_phone: String? = null
)

@Serializable
data class OnDemandPayoutResponse(
    val success: Boolean,
    val payout_id: String? = null,
    val trade_name: String? = null,
    val destination_type: String? = null,
    val net_npr: Double? = null,
    val instant_fee_npr: Double? = null,
    val utr: String? = null,
    val status: String? = null,
    val message: String? = null,
    val error: String? = null
)

@Singleton
class EvrryPartnerPayoutService @Inject constructor(
    private val supabase: SupabaseClient
) {
    /**
     * Request instant on-demand cash out (available 24/7).
     */
    suspend fun requestOnDemandPayout(
        partnerId: String,
        amountNpr: Double,
        destinationType: String = "bank",
        walletPhone: String? = null
    ): Result<OnDemandPayoutResponse> = runCatching {
        supabase.functions.invoke(
            function = "payout-execute",
            body = OnDemandPayoutRequest(
                partner_id = partnerId,
                amount_paisa = (amountNpr * 100).toLong(),
                destination_type = destinationType,
                wallet_phone = walletPhone
            )
        )
    }
}
