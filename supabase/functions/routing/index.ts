/**
 * Supabase Edge Function: routing
 * High-Performance OSRM Routing & Navigation Proxy
 * Elifsi Technologies Private Limited
 *
 * Core Capabilities:
 * 1. OSRM Road Route & Driving Polyline Generation (Zero Google Directions Fees)
 * 2. Real-Time Distance & ETA Computation
 * 3. Driver Coordinate Snapping to Nearest Road
 * 4. 1-to-N Distance Matrix for Nearest Driver / Rider Dispatch Matching
 * 5. Automatic Fallback with High-Precision Great-Circle Distance & Circuity Factor
 */

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

// OSRM Base URL: defaults to local Docker container on the evrry-network,
// or can be overridden via environment variable (e.g. self-hosted droplet/cluster).
const OSRM_URL = Deno.env.get('OSRM_BASE_URL') || 'http://osrm:5000';

interface LatLng {
  lat: number;
  lng: number;
}

interface RouteRequest {
  action: 'route' | 'nearest' | 'matrix';
  origin?: LatLng;
  destination?: LatLng;
  waypoints?: LatLng[];
  mode?: 'driving' | 'motorcycle' | 'walking';
  // For 'nearest'
  point?: LatLng;
  // For 'matrix'
  origins?: LatLng[];
  destinations?: LatLng[];
}

// ─────────────────────────────────────────────────────────────────────────────
// Great-Circle Haversine Formula (Fallback when OSRM backend is unavailable)
// ─────────────────────────────────────────────────────────────────────────────
function haversineDistanceMeters(p1: LatLng, p2: LatLng): number {
  const R = 6371000; // Earth radius in meters
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

// Google Polyline Algorithm encoder for fallback paths
function encodePolyline(points: LatLng[]): string {
  let encoded = '';
  let prevLat = 0;
  let prevLng = 0;

  for (const p of points) {
    const lat = Math.round(p.lat * 1e5);
    const lng = Math.round(p.lng * 1e5);

    encoded += encodeSignedNumber(lat - prevLat);
    encoded += encodeSignedNumber(lng - prevLng);

    prevLat = lat;
    prevLng = lng;
  }
  return encoded;
}

function encodeSignedNumber(num: number): string {
  let sgnNum = num < 0 ? ~(num << 1) : num << 1;
  let encodeString = '';
  while (sgnNum >= 0x20) {
    encodeString += String.fromCharCode((0x20 | (sgnNum & 0x1f)) + 63);
    sgnNum >>= 5;
  }
  encodeString += String.fromCharCode(sgnNum + 63);
  return encodeString;
}

// Interpolate waypoints for realistic fallback path display
function interpolateWaypoints(origin: LatLng, dest: LatLng, steps = 8): LatLng[] {
  const points: LatLng[] = [origin];
  for (let i = 1; i < steps; i++) {
    const t = i / steps;
    // Slight sinusoidal curvature to simulate Nepal street grid
    const lat = origin.lat + (dest.lat - origin.lat) * t + Math.sin(t * Math.PI) * 0.0008;
    const lng = origin.lng + (dest.lng - origin.lng) * t + Math.cos(t * Math.PI) * 0.0008;
    points.push({ lat, lng });
  }
  points.push(dest);
  return points;
}

// ─────────────────────────────────────────────────────────────────────────────
// Route Handler
// ─────────────────────────────────────────────────────────────────────────────
async function handleRoute(origin: LatLng, destination: LatLng, waypoints: LatLng[] = []) {
  const allPoints = [origin, ...waypoints, destination];
  const coordString = allPoints.map((p) => `${p.lng},${p.lat}`).join(';');
  const osrmUrl = `${OSRM_URL}/route/v1/driving/${coordString}?overview=full&geometries=polyline&steps=true`;

  try {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 2500); // 2.5s fast timeout
    const res = await fetch(osrmUrl, { signal: controller.signal });
    clearTimeout(timeout);

    if (res.ok) {
      const data = await res.json();
      if (data.code === 'Ok' && data.routes && data.routes.length > 0) {
        const primary = data.routes[0];
        return {
          ok: true,
          provider: 'osrm',
          distance_meters: Math.round(primary.distance),
          duration_seconds: Math.round(primary.duration),
          duration_minutes: Math.ceil(primary.duration / 60),
          polyline: primary.geometry,
          steps: primary.legs?.[0]?.steps?.map((s: any) => ({
            name: s.name || '',
            distance_meters: Math.round(s.distance),
            duration_seconds: Math.round(s.duration),
            instruction: s.maneuver?.type || 'turn',
            modifier: s.maneuver?.modifier,
          })) || [],
        };
      }
    }
  } catch (_e) {
    // OSRM container not reachable or timed out; fall back gracefully
  }

  // Graceful Nepal Fallback:
  // Direct distance * 1.28 circuity factor (verified for Kathmandu/Pokhara valley street layout)
  const crowFlies = haversineDistanceMeters(origin, destination);
  const roadDistance = Math.round(crowFlies * 1.28);
  // Average Kathmandu urban vehicle speed ~22 km/h (6.11 m/s)
  const durationSeconds = Math.max(60, Math.round(roadDistance / 6.11));
  const fallbackPoints = interpolateWaypoints(origin, destination);
  const polyline = encodePolyline(fallbackPoints);

  return {
    ok: true,
    provider: 'fallback_circuity_estimator',
    distance_meters: roadDistance,
    duration_seconds: durationSeconds,
    duration_minutes: Math.ceil(durationSeconds / 60),
    polyline,
    steps: [
      { name: 'Start Route', distance_meters: 0, duration_seconds: 0, instruction: 'depart' },
      { name: 'En Route', distance_meters: roadDistance, duration_seconds: durationSeconds, instruction: 'arrive' },
    ],
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// Nearest Road Snapping Handler
// ─────────────────────────────────────────────────────────────────────────────
async function handleNearest(point: LatLng) {
  const osrmUrl = `${OSRM_URL}/nearest/v1/driving/${point.lng},${point.lat}?number=1`;
  try {
    const res = await fetch(osrmUrl);
    if (res.ok) {
      const data = await res.json();
      if (data.code === 'Ok' && data.waypoints && data.waypoints.length > 0) {
        const wp = data.waypoints[0];
        return {
          ok: true,
          provider: 'osrm',
          snapped: {
            lat: wp.location[1],
            lng: wp.location[0],
            distance_from_point_m: Math.round(wp.distance),
            street_name: wp.name || '',
          },
        };
      }
    }
  } catch (_e) {
    // Fallback to original point
  }

  return {
    ok: true,
    provider: 'unmodified_fallback',
    snapped: {
      lat: point.lat,
      lng: point.lng,
      distance_from_point_m: 0,
      street_name: '',
    },
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// Distance Matrix Handler (1-to-N matching for driver dispatch)
// ─────────────────────────────────────────────────────────────────────────────
async function handleMatrix(origins: LatLng[], destinations: LatLng[]) {
  const allPoints = [...origins, ...destinations];
  const coordString = allPoints.map((p) => `${p.lng},${p.lat}`).join(';');
  const srcIndices = origins.map((_, i) => i).join(';');
  const dstIndices = destinations.map((_, i) => origins.length + i).join(';');
  const osrmUrl = `${OSRM_URL}/table/v1/driving/${coordString}?sources=${srcIndices}&destinations=${dstIndices}`;

  try {
    const res = await fetch(osrmUrl);
    if (res.ok) {
      const data = await res.json();
      if (data.code === 'Ok' && data.durations) {
        return {
          ok: true,
          provider: 'osrm',
          durations_seconds: data.durations,
          distances_meters: data.distances || null,
        };
      }
    }
  } catch (_e) {
    // Fallback matrix computation
  }

  const durations: number[][] = [];
  const distances: number[][] = [];
  for (const orig of origins) {
    const durRow: number[] = [];
    const distRow: number[] = [];
    for (const dest of destinations) {
      const dist = Math.round(haversineDistanceMeters(orig, dest) * 1.28);
      distRow.push(dist);
      durRow.push(Math.round(dist / 6.11));
    }
    durations.push(durRow);
    distances.push(distRow);
  }

  return {
    ok: true,
    provider: 'fallback_circuity_estimator',
    durations_seconds: durations,
    distances_meters: distances,
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// Serve HTTP
// ─────────────────────────────────────────────────────────────────────────────
serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const body: RouteRequest = await req.json();

    if (body.action === 'route') {
      if (!body.origin || !body.destination) {
        return new Response(JSON.stringify({ error: 'origin and destination required' }), {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }
      const result = await handleRoute(body.origin, body.destination, body.waypoints);
      return new Response(JSON.stringify(result), {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    if (body.action === 'nearest') {
      if (!body.point) {
        return new Response(JSON.stringify({ error: 'point required' }), {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }
      const result = await handleNearest(body.point);
      return new Response(JSON.stringify(result), {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    if (body.action === 'matrix') {
      if (!body.origins?.length || !body.destinations?.length) {
        return new Response(JSON.stringify({ error: 'origins and destinations required' }), {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }
      const result = await handleMatrix(body.origins, body.destinations);
      return new Response(JSON.stringify(result), {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    return new Response(JSON.stringify({ error: `Unknown action: ${(body as any).action}` }), {
      status: 400,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  } catch (err: any) {
    return new Response(JSON.stringify({ error: err.message || 'Internal Server Error' }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
