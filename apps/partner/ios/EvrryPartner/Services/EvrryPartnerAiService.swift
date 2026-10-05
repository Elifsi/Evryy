//
//  EvrryPartnerAiService.swift
//  EvrryPartner
//
//  Elifsi Technologies Private Limited
//  Partner AI Co-Pilot: Photo-to-Menu OCR & Kitchen Voice Command Execution
//

import Foundation
import Supabase

public struct DraftItem: Codable {
    public let name: String
    public let price_npr: Double
    public let category: String
    public let description: String?
}

public struct PhotoMenuResult: Codable {
    public let success: Bool
    public let items_extracted_count: Int?
    public let draft_catalog_items: [DraftItem]?
    public let error: String?
}

public struct KitchenVoiceResult: Codable {
    public let success: Bool
    public let item_name: String?
    public let is_available: Bool?
    public let confirmation_voice_reply: String?
    public let error: String?
}

private struct PhotoMenuBody: Codable {
    let action: String = "photo_to_menu"
    let image_base64: String
}

private struct KitchenVoiceBody: Codable {
    let action: String = "kitchen_voice"
    let prompt: String
    let partner_id: String
}

public final class EvrryPartnerAiService {
    private let client: SupabaseClient
    
    public init(client: SupabaseClient) {
        self.client = client
    }
    
    public func parseMenuPhoto(imageBase64: String) async throws -> PhotoMenuResult {
        let body = PhotoMenuBody(image_base64: imageBase64)
        return try await client.functions.invoke(
            "ai-gateway",
            options: FunctionInvokeOptions(body: body)
        )
    }
    
    public func executeKitchenVoice(phrase: String, partnerId: String) async throws -> KitchenVoiceResult {
        let body = KitchenVoiceBody(prompt: phrase, partner_id: partnerId)
        return try await client.functions.invoke(
            "ai-gateway",
            options: FunctionInvokeOptions(body: body)
        )
    }
}
