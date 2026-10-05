package com.elifsi.evrry.partner.network

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.functions.functions
import kotlinx.serialization.Serializable
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Evrry Partner Map & Routing Service (Driver / Delivery Partner Android)
 * Elifsi Technologies Private Limited
 *
 * Provides real-time navigation paths, turn-by-turn maneuvers, nearest road snapping,
 * and location broadcast to the public.driver_locations table and Realtime channels.
 */

@Serializable
data class PartnerLatLngDto(
    val lat: Double,
    val lng: Double
)

@Serializable
data class PartnerRouteStepDto(
    val name: String,
    val distance_meters: Long,
    val duration_seconds: Long,
    val instruction: String,
    val modifier: String? = null
)

@Serializable
data class PartnerRouteResponsePayload(
    val ok: Boolean,
    val provider: String,
    val distance_meters: Long,
    val duration_seconds: Long,
    val duration_minutes: Int,
    val polyline: String,
    val steps: List<PartnerRouteStepDto> = emptyList()
)

@Serializable
data class PartnerSnapResponsePayload(
    val ok: Boolean,
    val provider: String,
    val snapped: PartnerSnappedPointDto
)

@Serializable
data class PartnerSnappedPointDto(
    val lat: Double,
    val lng: Double,
    val distance_from_point_m: Long,
    val street_name: String
)

@Singleton
class EvrryPartnerMapRoutingService @Inject constructor(
    private val supabaseClient: SupabaseClient
) {
    /**
     * Compute navigation route to customer pickup or dropoff point
     */
    suspend fun getNavigationRoute(
        originLat: Double,
        originLng: Double,
        destLat: Double,
        destLng: Double
    ): Result<PartnerRouteResponsePayload> = runCatching {
        val payload = mapOf(
            "action" to "route",
            "origin" to mapOf("lat" to originLat, "lng" to originLng),
            "destination" to mapOf("lat" to destLat, "lng" to destLng),
            "mode" to "driving"
        )
        supabaseClient.functions.invoke("routing", body = payload)
    }

    /**
     * Snaps current raw GPS reading to road network before broadcasting location
     */
    suspend fun snapToRoad(lat: Double, lng: Double): Result<PartnerSnapResponsePayload> = runCatching {
        val payload = mapOf(
            "action" to "nearest",
            "point" to mapOf("lat" to lat, "lng" to lng)
        )
        supabaseClient.functions.invoke("routing", body = payload)
    }
}
