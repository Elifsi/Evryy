//
//  EvrryPushService.swift
//  EvrryConsumer
//
//  Elifsi Technologies Private Limited
//  Registers APNs / FCM Push Tokens for iOS Consumer
//

import Foundation
import Supabase

private struct RegisterDeviceTokenArgs: Codable {
    let p_token: String
    let p_platform: String = "ios"
    let p_app_variant: String = "consumer"
    let p_device_model: String?
    let p_partner_id: String?
}

private struct UnregisterDeviceTokenArgs: Codable {
    let p_token: String
}

public final class EvrryPushService {
    private let client: SupabaseClient
    
    public init(client: SupabaseClient) {
        self.client = client
    }
    
    /// Registers APNs device token with central backend
    public func registerDeviceToken(apnsToken: String, deviceModel: String? = nil) async throws -> String {
        let args = RegisterDeviceTokenArgs(
            p_token: apnsToken,
            p_device_model: deviceModel,
            p_partner_id: nil
        )
        return try await client.database.rpc("register_device_token", params: args).execute().value
    }
    
    /// Unregisters device token upon user sign-out
    public func unregisterDeviceToken(apnsToken: String) async throws {
        let args = UnregisterDeviceTokenArgs(p_token: apnsToken)
        try await client.database.rpc("unregister_device_token", params: args).execute()
    }
}
