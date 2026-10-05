//
//  EvrryAiService.swift
//  EvrryConsumer
//
//  Elifsi Technologies Private Limited
//  Server-Side AI Concierge Bridge for iOS Consumer
//

import Foundation
import Supabase

private struct VoiceChatBody: Codable {
    let action: String = "voice_concierge"
    let prompt: String
    let user_id: String?
}

public struct VoiceChatResult: Codable {
    public let success: Bool
    public let reply: String
    public let mock: Bool?
    public let user_context_injected: Bool?
    public let error: String?
}

public final class EvrryAiService {
    private let client: SupabaseClient
    
    public init(client: SupabaseClient) {
        self.client = client
    }
    
    public func chatWithConcierge(prompt: String, userId: String? = nil) async throws -> VoiceChatResult {
        let body = VoiceChatBody(prompt: prompt, user_id: userId)
        return try await client.functions.invoke(
            "ai-gateway",
            options: FunctionInvokeOptions(body: body)
        )
    }
}
