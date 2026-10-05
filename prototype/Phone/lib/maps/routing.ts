/**
 * Prototype Map & Routing Service
 * Computes road distance, driving duration, and polyline geometries
 * with support for OSRM backend and realistic Nepal road network modeling.
 */

import { decodePolyline, encodePolyline, LatLng } from "./polyline";

export interface RouteResult {
  distanceMeters: number;
  durationSeconds: number;
  durationMinutes: number;
  polyline: string;
  points: LatLng[];
  provider: "osrm" | "circuity_model";
}

/**
 * Great-circle Haversine formula
 */
export function haversineMeters(p1: LatLng, p2: LatLng): number {
  const R = 6371000;
  const dLat = ((p2.lat - p1.lat) * Math.PI) / 180;
  const dLng = ((p2.lng - p1.lng) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos((p1.lat * Math.PI) / 180) *
      Math.cos((p2.lat * Math.PI) / 180) *
      Math.sin(dLng / 2) *
      Math.sin(dLng / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return Math.round(R * c);
}

/**
 * Calculates road routing between two geographic points in Nepal.
 * If OSRM endpoint is passed or available, fetches live road graph;
 * otherwise uses 1.28 circuity factor and generates smooth polyline.
 */
export async function calculateRoute(
  origin: LatLng,
  destination: LatLng,
  osrmEndpoint?: string
): Promise<RouteResult> {
  if (osrmEndpoint) {
    try {
      const url = `${osrmEndpoint}/route/v1/driving/${origin.lng},${origin.lat};${destination.lng},${destination.lat}?overview=full&geometries=polyline`;
      const res = await fetch(url, { signal: AbortSignal.timeout(2000) });
      if (res.ok) {
        const data = await res.json();
        if (data.code === "Ok" && data.routes?.[0]) {
          const r = data.routes[0];
          return {
            distanceMeters: Math.round(r.distance),
            durationSeconds: Math.round(r.duration),
            durationMinutes: Math.ceil(r.duration / 60),
            polyline: r.geometry,
            points: decodePolyline(r.geometry),
            provider: "osrm",
          };
        }
      }
    } catch {
      // Fall through to deterministic circuity model
    }
  }

  // Circuity model (1.28x road factor for Kathmandu / Nepal valley topography)
  const crowFlies = haversineMeters(origin, destination);
  const distanceMeters = Math.round(crowFlies * 1.28);
  // Average vehicle speed 22 km/h (6.11 m/s)
  const durationSeconds = Math.max(60, Math.round(distanceMeters / 6.11));

  // Generate 8 interpolated waypoints with slight curve
  const steps = 8;
  const points: LatLng[] = [origin];
  for (let i = 1; i < steps; i++) {
    const t = i / steps;
    const lat = origin.lat + (destination.lat - origin.lat) * t + Math.sin(t * Math.PI) * 0.0008;
    const lng = origin.lng + (destination.lng - origin.lng) * t + Math.cos(t * Math.PI) * 0.0008;
    points.push({ lat: Number(lat.toFixed(6)), lng: Number(lng.toFixed(6)) });
  }
  points.push(destination);

  const polyline = encodePolyline(points);

  return {
    distanceMeters,
    durationSeconds,
    durationMinutes: Math.ceil(durationSeconds / 60),
    polyline,
    points,
    provider: "circuity_model",
  };
}
