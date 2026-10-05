package com.elifsi.evrry.consumer.network

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.functions.functions
import kotlinx.serialization.Serializable
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Evrry Map & Routing Service (Consumer Android)
 * Elifsi Technologies Private Limited
 *
 * Interacts with the Supabase Routing Edge Function (powered by self-hosted OSRM)
 * to compute road navigation paths, turn-by-turn steps, and live ETAs with
 * ZERO Google Directions API charges.
 *
 * Map visual tiles and markers are rendered using Google Maps SDK for Android
 * (free unlimited mobile tier).
 */

@Serializable
data class LatLngDto(
    val lat: Double,
    val lng: Double
)

@Serializable
data class RouteStepDto(
    val name: String,
    val distance_meters: Long,
    val duration_seconds: Long,
    val instruction: String,
    val modifier: String? = null
)

@Serializable
data class RouteRequestPayload(
    val action: String = "route",
    val origin: LatLngDto,
    val destination: LatLngDto,
    val waypoints: List<LatLngDto> = emptyList(),
    val mode: String = "driving"
)

@Serializable
data class RouteResponsePayload(
    val ok: Boolean,
    val provider: String,
    val distance_meters: Long,
    val duration_seconds: Long,
    val duration_minutes: Int,
    val polyline: String,
    val steps: List<RouteStepDto> = emptyList()
)

@Serializable
data class SnapRequestPayload(
    val action: String = "nearest",
    val point: LatLngDto
)

@Serializable
data class SnappedPointDto(
    val lat: Double,
    val lng: Double,
    val distance_from_point_m: Long,
    val street_name: String
)

@Serializable
data class SnapResponsePayload(
    val ok: Boolean,
    val provider: String,
    val snapped: SnappedPointDto
)

@Singleton
class EvrryMapRoutingService @Inject constructor(
    private val supabaseClient: SupabaseClient
) {
    /**
     * Calculates the turn-by-turn driving route and encoded polyline between two locations.
     */
    suspend fun getRoute(
        originLat: Double,
        originLng: Double,
        destLat: Double,
        destLng: Double,
        waypoints: List<LatLngDto> = emptyList(),
        mode: String = "driving"
    ): Result<RouteResponsePayload> = runCatching {
        val payload = RouteRequestPayload(
            action = "route",
            origin = LatLngDto(originLat, originLng),
            destination = LatLngDto(destLat, destLng),
            waypoints = waypoints,
            mode = mode
        )
        supabaseClient.functions.invoke("routing", body = payload)
    }

    /**
     * Snaps a raw GPS point to the nearest drivable road segment in Nepal.
     */
    suspend fun snapToRoad(lat: Double, lng: Double): Result<SnapResponsePayload> = runCatching {
        val payload = SnapRequestPayload(
            action = "nearest",
            point = LatLngDto(lat, lng)
        )
        supabaseClient.functions.invoke("routing", body = payload)
    }

    companion object {
        /**
         * Decodes a Google/OSRM encoded polyline string into a list of latitude/longitude pairs
         * for rendering in Google Maps Compose (Polyline).
         */
        fun decodePolyline(encoded: String): List<Pair<Double, Double>> {
            val poly = ArrayList<Pair<Double, Double>>()
            var index = 0
            val len = encoded.length
            var lat = 0
            var lng = 0

            while (index < len) {
                var b: Int
                var shift = 0
                var result = 0
                do {
                    b = encoded[index++].code - 63
                    result = result or ((b and 0x1f) shl shift)
                    shift += 5
                } while (b >= 0x20)
                val dlat = if ((result and 1) != 0) (result shr 1).inv() else (result shr 1)
                lat += dlat

                shift = 0
                result = 0
                do {
                    b = encoded[index++].code - 63
                    result = result or ((b and 0x1f) shl shift)
                    shift += 5
                } while (b >= 0x20)
                val dlng = if ((result and 1) != 0) (result shr 1).inv() else (result shr 1)
                lng += dlng

                poly.add(Pair(lat / 1e5, lng / 1e5))
            }
            return poly
        }
    }
}
