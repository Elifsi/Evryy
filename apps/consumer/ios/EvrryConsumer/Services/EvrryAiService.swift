//
//  EvrryAiService.swift
//  EvrryConsumer
//
//  Elifsi Technologies Private Limited
//  Server-Side AI Concierge & Real-Time Voice Bridge for iOS Consumer
//

import Foundation
import Supabase

public enum VoicePersona: String, Codable {
    case eli = "eli"
    case rony = "rony"
    case jenny = "jenny"
    case sol = "sol"
}

public struct VoicePersonaMeta: Codable {
    public let id: String
    public let name: String
    public let gender: String
    public let tagline: String
    public let tone: String
    public let tts_voice_code: String?
    public let pitch: Double?
    public let speed: Double?
    public let sample_greeting: String?
}

private struct VoiceChatBody: Codable {
    let action: String = "voice_concierge"
    let prompt: String
    let user_id: String?
    let persona: String?
}

public struct VoiceChatResult: Codable {
    public let success: Bool
    public let reply: String
    public let persona: String?
    public let persona_name: String?
    public let mock: Bool?
    public let user_context_injected: Bool?
    public let error: String?
}

private struct VoiceRoomBody: Codable {
    let action: String = "create_voice_room"
    let persona: String
    let user_id: String?
}

public struct VoiceRoomResult: Codable {
    public let success: Bool
    public let room_name: String
    public let server_url: String
    public let token: String
    public let persona: VoicePersonaMeta
    public let websocket_fallback_url: String?
    public let is_mock: Bool?
    public let error: String?
}

private struct SetPersonaParams: Codable {
    let p_persona: String
    let p_speed: Double
}

public final class EvrryAiService {
    private let client: SupabaseClient
    
    public init(client: SupabaseClient) {
        self.client = client
    }
    
    public func chatWithConcierge(
        prompt: String,
        persona: VoicePersona = .eli,
        userId: String? = nil
    ) async throws -> VoiceChatResult {
        let body = VoiceChatBody(
            prompt: prompt,
            user_id: userId,
            persona: persona.rawValue
        )
        return try await client.functions.invoke(
            "ai-gateway",
            options: FunctionInvokeOptions(body: body)
        )
    }

    public func createVoiceRoom(
        persona: VoicePersona = .eli,
        userId: String? = nil
    ) async throws -> VoiceRoomResult {
        let body = VoiceRoomBody(
            persona: persona.rawValue,
            user_id: userId
        )
        return try await client.functions.invoke(
            "ai-gateway",
            options: FunctionInvokeOptions(body: body)
        )
    }

    public func setPreferredPersona(
        persona: VoicePersona,
        speed: Double = 1.0
    ) async throws {
        let params = SetPersonaParams(
            p_persona: persona.rawValue,
            p_speed: speed
        )
        try await client.database
            .rpc("set_preferred_voice_persona", params: params)
            .execute()
    }
}
