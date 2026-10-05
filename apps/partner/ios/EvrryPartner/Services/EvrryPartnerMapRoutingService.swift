//
//  EvrryPartnerMapRoutingService.swift
//  EvrryPartner
//
//  Elifsi Technologies Private Limited
//  Partner Driver / Delivery Route Navigation & GPS Snapping
//

import Foundation
import CoreLocation
import Supabase

public final class EvrryPartnerMapRoutingService {
    public static let shared = EvrryPartnerMapRoutingService()
    private init() {}
    
    public func getNavigationRoute(
        client: SupabaseClient,
        origin: CLLocationCoordinate2D,
        destination: CLLocationCoordinate2D
    ) async throws -> [String: Any] {
        let payload: [String: Any] = [
            "action": "route",
            "origin": ["lat": origin.latitude, "lng": origin.longitude],
            "destination": ["lat": destination.latitude, "lng": destination.longitude],
            "mode": "driving"
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: payload)
        let responseData: Data = try await client.functions
            .invoke("routing", options: FunctionInvokeOptions(body: jsonData))
        let dict = try JSONSerialization.jsonObject(with: responseData) as? [String: Any] ?? [:]
        return dict
    }
    
    public func snapToRoad(
        client: SupabaseClient,
        coordinate: CLLocationCoordinate2D
    ) async throws -> (lat: Double, lng: Double, streetName: String) {
        let payload: [String: Any] = [
            "action": "nearest",
            "point": ["lat": coordinate.latitude, "lng": coordinate.longitude]
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: payload)
        let responseData: Data = try await client.functions
            .invoke("routing", options: FunctionInvokeOptions(body: jsonData))
        guard let dict = try JSONSerialization.jsonObject(with: responseData) as? [String: Any],
              let snapped = dict["snapped"] as? [String: Any],
              let lat = snapped["lat"] as? Double,
              let lng = snapped["lng"] as? Double else {
            return (coordinate.latitude, coordinate.longitude, "")
        }
        return (lat, lng, snapped["street_name"] as? String ?? "")
    }
}
