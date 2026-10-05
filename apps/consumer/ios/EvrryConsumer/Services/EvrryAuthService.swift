//
//  EvrryAuthService.swift
//  EvrryConsumer
//
//  Elifsi Technologies Private Limited
//  Nepal Mobile SMS OTP Authentication (NTC/Ncell) via Supabase
//

import Foundation
import Supabase

public struct DirectSmsPayload: Codable {
    public let phone: String
    public let otp: String?
    
    public init(phone: String, otp: String? = nil) {
        self.phone = phone
        self.otp = otp
    }
}

public struct DirectSmsResponse: Codable {
    public let success: Bool
    public let provider: String?
    public let mock: Bool?
    public let otp: String?
    public let error: String?
    public let retry_after_seconds: Int?
}

public final class EvrryAuthService {
    private let client: SupabaseClient
    
    public init(client: SupabaseClient) {
        self.client = client
    }
    
    /// Requests 6-digit OTP code to a Nepal mobile number
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
    public func requestDirectMockSms(phoneNumber: String) async throws -> DirectSmsResponse {
        let normalized = normalizeNepalPhone(phoneNumber)
        return try await client.functions.invoke(
            "send-sms",
            options: FunctionInvokeOptions(body: DirectSmsPayload(phone: normalized))
        )
    }
    
    private func normalizeNepalPhone(_ raw: String) -> String {
        let digits = raw.filter { "0123456789".contains($0) }
        if digits.hasPrefix("977") {
            return "+\(digits)"
        } else if digits.count == 10 {
            return "+977\(digits)"
        }
        return raw
    }
}
