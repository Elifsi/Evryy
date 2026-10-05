//
//  EvrryPartnerPayoutService.swift
//  EvrryPartner
//
//  Elifsi Technologies Private Limited
//  On-Demand Instant Payouts & Settlement Statements
//

import Foundation
import Supabase

private struct OnDemandPayoutBody: Codable {
    let action: String = "on_demand_payout"
    let partner_id: String
    let amount_paisa: Int64
    let destination_type: String
    let wallet_phone: String?
}

public struct OnDemandPayoutResult: Codable {
    public let success: Bool
    public let payout_id: String?
    public let trade_name: String?
    public let destination_type: String?
    public let net_npr: Double?
    public let instant_fee_npr: Double?
    public let utr: String?
    public let status: String?
    public let message: String?
    public let error: String?
}

public final class EvrryPartnerPayoutService {
    private let client: SupabaseClient
    
    public init(client: SupabaseClient) {
        self.client = client
    }
    
    /// Requests instant 24/7 on-demand cash out
    public func requestOnDemandPayout(
        partnerId: String,
        amountNpr: Double,
        destinationType: String = "bank",
        walletPhone: String? = nil
    ) async throws -> OnDemandPayoutResult {
        let body = OnDemandPayoutBody(
            partner_id: partnerId,
            amount_paisa: Int64(amountNpr * 100),
            destination_type: destinationType,
            wallet_phone: walletPhone
        )
        return try await client.functions.invoke(
            "payout-execute",
            options: FunctionInvokeOptions(body: body)
        )
    }
}
