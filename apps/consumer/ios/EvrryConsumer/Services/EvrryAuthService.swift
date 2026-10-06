//
//  EvrryAuthService.swift
//  EvrryConsumer
//
//  Elifsi Technologies Private Limited
//  WhatsApp Cloud API Primary OTP with Domestic SMS Fallback via Supabase
//

import Foundation
import Supabase

public struct DirectOtpPayload: Codable {
    public let phone: String
    public let channel: String?
    public let otp: String?
    
    public init(phone: String, channel: String? = "whatsapp", otp: String? = nil) {
        self.phone = phone
        self.channel = channel
        self.otp = otp
    }
}

public struct DirectOtpResponse: Codable {
    public let success: Bool
    public let channel: String?
    public let provider: String?
    public let mock: Bool?
    public let otp: String?
    public let error: String?
    public let message: String?
    public let retry_after_seconds: Int?
}

// Backward compatibility aliases
public typealias DirectSmsPayload = DirectOtpPayload
public typealias DirectSmsResponse = DirectOtpResponse

public final class EvrryAuthService {
    private let client: SupabaseClient
    
    public init(client: SupabaseClient) {
        self.client = client
    }
    
    /// Requests 6-digit WhatsApp OTP verification code
    public func requestWhatsAppOtp(phoneNumber: String) async throws -> DirectOtpResponse {
        let normalized = normalizeNepalPhone(phoneNumber)
        return try await client.functions.invoke(
            "send-otp",
            options: FunctionInvokeOptions(body: DirectOtpPayload(phone: normalized, channel: "whatsapp"))
        )
    }

    /// Requests OTP code specifying channel ("whatsapp" or "sms")
    public func requestOtp(phoneNumber: String, channel: String = "whatsapp") async throws -> DirectOtpResponse {
        let normalized = normalizeNepalPhone(phoneNumber)
        return try await client.functions.invoke(
            "send-otp",
            options: FunctionInvokeOptions(body: DirectOtpPayload(phone: normalized, channel: channel))
        )
    }

    /// Requests 6-digit OTP code to a Nepal mobile number via Supabase Auth
    public func signInWithPhone(phoneNumber: String) async throws {
        let normalized = normalizeNepalPhone(phoneNumber)
        try await client.auth.signInWithOTP(phone: normalized)
    }
    
    /// Verifies 6-digit OTP code and logs the user in
    public func verifyPhoneOtp(phoneNumber: String, token: String) async throws {
        let normalized = normalizeNepalPhone(phoneNumber)
        try await client.auth.verifyOTP(
            phone: normalized,
            token: token,
            type: .sms
        )
    }
    
    /// Invokes the send-sms Edge Function directly (returns mock OTP in development)
    public func requestDirectMockSms(phoneNumber: String) async throws -> DirectOtpResponse {
        let normalized = normalizeNepalPhone(phoneNumber)
        return try await client.functions.invoke(
            "send-sms",
            options: FunctionInvokeOptions(body: DirectOtpPayload(phone: normalized, channel: "sms"))
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
