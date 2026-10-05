//
//  EvrryPaymentService.swift
//  EvrryConsumer
//
//  Elifsi Technologies Private Limited
//  Nepal Direct Payment Gateway Bridges (eSewa, Khalti, Fonepay)
//

import Foundation
import Supabase

public struct EsewaFormParamsPayload: Codable {
    public let amount: String
    public let tax_amount: String
    public let total_amount: String
    public let transaction_uuid: String
    public let product_code: String
    public let product_service_charge: String
    public let product_delivery_charge: String
    public let success_url: String
    public let failure_url: String
    public let signed_field_names: String
    public let signature: String
}

public struct PaymentInitiateResponsePayload: Codable {
    public let success: Bool
    public let provider: String
    public let is_sandbox: Bool?
    public let gateway_url: String?
    public let form_params: EsewaFormParamsPayload?
    public let pidx: String?
    public let payment_url: String?
    public let expires_at: String?
    public let qr_string: String?
    public let prn: String?
    public let amount_npr: String?
    public let error: String?
}

public struct PaymentVerifyResponsePayload: Codable {
    public let success: Bool
    public let payment_id: String?
    public let reference_id: String?
    public let provider: String?
    public let transaction_ref: String?
    public let amount_paisa: Int64?
    public let status: String?
    public let error: String?
    public let message: String?
}

private struct PaymentInitiateBody: Codable {
    let reference_type: String = "order"
    let reference_id: String
    let method: String
    let return_url: String?
}

private struct PaymentVerifyBody: Codable {
    let provider: String
    let reference_type: String = "order"
    let reference_id: String
    let pidx: String?
    let data: String?
    let transaction_uuid: String?
    let prn: String?
}

public final class EvrryPaymentService {
    private let client: SupabaseClient
    
    public init(client: SupabaseClient) {
        self.client = client
    }
    
    /// Requests a secure payment session from the server
    public func initiatePayment(
        orderId: String,
        method: String, // "esewa" | "khalti" | "fonepay_qr"
        returnUrl: String? = nil
    ) async throws -> PaymentInitiateResponsePayload {
        let body = PaymentInitiateBody(
            reference_id: orderId,
            method: method,
            return_url: returnUrl
        )
        return try await client.functions.invoke(
            "payment-initiate",
            options: FunctionInvokeOptions(body: body)
        )
    }
    
    /// Verifies gateway checkout completion and confirms order in double-entry ledger
    public func verifyPayment(
        orderId: String,
        provider: String,
        pidx: String? = nil,
        esewaData: String? = nil,
        transactionUuid: String? = nil,
        prn: String? = nil
    ) async throws -> PaymentVerifyResponsePayload {
        let body = PaymentVerifyBody(
            provider: provider,
            reference_id: orderId,
            pidx: pidx,
            data: esewaData,
            transaction_uuid: transactionUuid,
            prn: prn
        )
        return try await client.functions.invoke(
            "payment-verify",
            options: FunctionInvokeOptions(body: body)
        )
    }
}
