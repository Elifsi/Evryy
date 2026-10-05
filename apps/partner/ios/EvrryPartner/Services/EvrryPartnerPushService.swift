//
//  EvrryPartnerPushService.swift
//  EvrryPartner
//
//  Elifsi Technologies Private Limited
//  Registers APNs / FCM Push Tokens for iOS Partner (Kitchen / Hotel / Driver)
//

import Foundation
import Supabase

private struct RegisterPartnerDeviceArgs: Codable {
    let p_token: String
    let p_platform: String = "ios"
    let p_app_variant: String = "partner"
    let p_device_model: String?
    let p_partner_id: String?
}

private struct UnregisterPartnerDeviceArgs: Codable {
    let p_token: String
}

public final class EvrryPartnerPushService {
    private let client: SupabaseClient
    
    public init(client: SupabaseClient) {
        self.client = client
    }
    
    public func registerDeviceToken(apnsToken: String, partnerId: String, deviceModel: String? = nil) async throws -> String {
        let args = RegisterPartnerDeviceArgs(
            p_token: apnsToken,
            p_device_model: deviceModel,
            p_partner_id: partnerId
        )
        return try await client.database.rpc("register_device_token", params: args).execute().value
    }
    
    public func unregisterDeviceToken(apnsToken: String) async throws {
        let args = UnregisterPartnerDeviceArgs(p_token: apnsToken)
        try await client.database.rpc("unregister_device_token", params: args).execute()
    }
}
