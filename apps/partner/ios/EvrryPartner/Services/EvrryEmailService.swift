//
//  EvrryEmailService.swift
//  EvrryPartner
//
//  Elifsi Technologies Private Limited
//  Dispatches partner emails via Supabase Edge Function (`send-email`).
//

import Foundation
import Supabase

public struct PartnerKycPayload: Codable {
    public let tradeName: String
    public let status: String // "approved" or "rejected"
    public let rejectionReason: String?
    
    public init(tradeName: String, status: String, rejectionReason: String? = nil) {
        self.tradeName = tradeName
        self.status = status
        self.rejectionReason = rejectionReason
    }
}

public struct PartnerOtpPayload: Codable {
    public let recipientName: String?
    public let otpCode: String
    public let validMinutes: Int
    public let purpose: String?
    
    public init(recipientName: String? = nil, otpCode: String, validMinutes: Int = 10, purpose: String? = nil) {
        self.recipientName = recipientName
        self.otpCode = otpCode
        self.validMinutes = validMinutes
        self.purpose = purpose
    }
}

private struct SendKycEnvelope: Codable {
    let action: String = "partner_kyc_status"
    let to: String
    let kycData: PartnerKycPayload
}

private struct SendOtpEnvelope: Codable {
    let action: String = "verification_otp"
    let to: String
    let otpData: PartnerOtpPayload
}

public struct EmailDispatchResponse: Codable {
    public let success: Bool
    public let id: String?
    public let error: String?
    public let mock: Bool?
}

public final class EvrryPartnerEmailService {
    private let client: SupabaseClient
    
    public init(client: SupabaseClient) {
        self.client = client
    }
    
    /// Sends 6-digit email OTP for partner login / merchant verification
    public func sendVerificationOtp(to email: String, otpCode: String, tradeName: String? = nil) async throws -> EmailDispatchResponse {
        let envelope = SendOtpEnvelope(
            to: email,
            otpData: PartnerOtpPayload(
                recipientName: tradeName,
                otpCode: otpCode,
                purpose: "verify your merchant account"
            )
        )
        return try await client.functions.invoke(
            "send-email",
            options: FunctionInvokeOptions(body: envelope)
        )
    }
}
