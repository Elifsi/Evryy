//
//  EvrryAuthService.swift
//  EvrryPartner
//
//  Elifsi Technologies Private Limited
//  Partner Phone SMS Authentication
//

import Foundation
import Supabase

public final class EvrryPartnerAuthService {
    private let client: SupabaseClient
    
    public init(client: SupabaseClient) {
        self.client = client
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
