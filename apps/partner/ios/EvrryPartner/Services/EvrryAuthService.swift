//
//  EvrryAuthService.swift
//  EvrryPartner
//
//  Elifsi Technologies Private Limited
//  Partner Phone WhatsApp OTP & Domestic SMS Authentication
//

import Foundation
import Supabase

public struct PartnerOtpPayload: Codable {
    public let phone: String
    public let channel: String?
    
    public init(phone: String, channel: String? = "whatsapp") {
        self.phone = phone
        self.channel = channel
    }
}

public struct PartnerOtpResponse: Codable {
    public let success: Bool
    public let channel: String?
    public let provider: String?
    public let mock: Bool?
    public let otp: String?
    public let error: String?
    public let message: String?
}

public final class EvrryPartnerAuthService {
    private let client: SupabaseClient
    
    public init(client: SupabaseClient) {
        self.client = client
    }

    /// Requests 6-digit WhatsApp OTP verification code
    public func requestWhatsAppOtp(phoneNumber: String) async throws -> PartnerOtpResponse {
        let normalized = normalizeNepalPhone(phoneNumber)
        return try await client.functions.invoke(
            "send-otp",
            options: FunctionInvokeOptions(body: PartnerOtpPayload(phone: normalized, channel: "whatsapp"))
        )
    }

    /// Requests OTP code specifying channel ("whatsapp" or "sms")
    public func requestOtp(phoneNumber: String, channel: String = "whatsapp") async throws -> PartnerOtpResponse {
        let normalized = normalizeNepalPhone(phoneNumber)
        return try await client.functions.invoke(
            "send-otp",
            options: FunctionInvokeOptions(body: PartnerOtpPayload(phone: normalized, channel: channel))
        )
    }
    
    public func signInWithPhone(phoneNumber: String) async throws {
        let normalized = normalizeNepalPhone(phoneNumber)
        try await client.auth.signInWithOTP(phone: normalized)
    }
    
    public func verifyPhoneOtp(phoneNumber: String, token: String) async throws {
        let normalized = normalizeNepalPhone(phoneNumber)
        try await client.auth.verifyOTP(
            phone: normalized,
            token: token,
            type: .sms
        )
    }
    
    public func normalizeNepalPhone(_ raw: String) -> String {
        let digits = raw.filter { "0123456789".contains($0) }
        if digits.hasPrefix("977") {
            return "+\(digits)"
        } else if digits.count == 10 {
            return "+977\(digits)"
        }
        return raw
    }
}
