//
//  EvrryMapRoutingService.swift
//  EvrryConsumer
//
//  Elifsi Technologies Private Limited
//  OSRM Road Routing, Turn-by-Turn Maneuvers & Polylines (Zero Google Directions Fees)
//

import Foundation
import CoreLocation
import Supabase

public struct LatLngPoint: Codable {
    public let lat: Double
    public let lng: Double
    
    public init(lat: Double, lng: Double) {
        self.lat = lat
        self.lng = lng
    }
}

public struct RouteStepItem: Codable {
    public let name: String
    public let distance_meters: Int
    public let duration_seconds: Int
    public let instruction: String
    public let modifier: String?
}

public struct RouteResponseData: Codable {
    public let ok: Bool
    public let provider: String
    public let distance_meters: Int
    public let duration_seconds: Int
    public let duration_minutes: Int
    public let polyline: String
    public let steps: [RouteStepItem]?
}

public struct SnappedPointData: Codable {
    public let lat: Double
    public let lng: Double
    public let distance_from_point_m: Int
    public let street_name: String
}

public struct SnapResponseData: Codable {
    public let ok: Bool
    public let provider: String
    public let snapped: SnappedPointData
}

public final class EvrryMapRoutingService {
    public static let shared = EvrryMapRoutingService()
    private init() {}
    
    /**
     * Compute navigation route and encoded road polyline between origin and destination.
     */
    public func getRoute(
        client: SupabaseClient,
        origin: CLLocationCoordinate2D,
        destination: CLLocationCoordinate2D,
        waypoints: [CLLocationCoordinate2D] = []
    ) async throws -> RouteResponseData {
        let payload: [String: Any] = [
            "action": "route",
            "origin": ["lat": origin.latitude, "lng": origin.longitude],
            "destination": ["lat": destination.latitude, "lng": destination.longitude],
            "waypoints": waypoints.map { ["lat": $0.latitude, "lng": $0.longitude] },
            "mode": "driving"
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: payload)
        let response: RouteResponseData = try await client.functions
            .invoke("routing", options: FunctionInvokeOptions(body: jsonData))
        return response
    }
    
    /**
     * Snap coordinate to nearest drivable road
     */
    public func snapToRoad(
        client: SupabaseClient,
        point: CLLocationCoordinate2D
    ) async throws -> SnapResponseData {
        let payload: [String: Any] = [
            "action": "nearest",
            "point": ["lat": point.latitude, "lng": point.longitude]
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: payload)
        let response: SnapResponseData = try await client.functions
            .invoke("routing", options: FunctionInvokeOptions(body: jsonData))
        return response
    }
    
    /**
     * Decode standard encoded polyline string to array of CLLocationCoordinate2D for MapKit / Google Maps overlay
     */
    public static func decodePolyline(_ encoded: String) -> [CLLocationCoordinate2D] {
        var coords = [CLLocationCoordinate2D]()
        var index = encoded.startIndex
        var lat = 0
        var lng = 0
        
        while index < encoded.endIndex {
            var b: Int
            var shift = 0
            var result = 0
            repeat {
                b = Int(encoded[index].asciiValue ?? 63) - 63
                index = encoded.index(after: index)
                result |= (b & 0x1f) << shift
                shift += 5
            } while b >= 0x20
            let dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1))
            lat += dlat
            
            shift = 0
            result = 0
            repeat {
                b = Int(encoded[index].asciiValue ?? 63) - 63
                index = encoded.index(after: index)
                result |= (b & 0x1f) << shift
                shift += 5
            } while b >= 0x20
            let dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1))
            lng += dlng
            
            coords.append(CLLocationCoordinate2D(latitude: Double(lat) / 1e5, longitude: Double(lng) / 1e5))
        }
        return coords
    }
}
