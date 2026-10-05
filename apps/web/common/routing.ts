/**
 * Web Map & Routing Helper (Next.js / TypeScript)
 * Elifsi Technologies Private Limited
 *
 * Connects Web Apps (Consumer, Partner, and Superadmin Admin Console) to the
 * self-hosted OSRM engine via the Supabase Routing Edge Function.
 *
 * Provides polyline decoding for Mapbox GL / Leaflet / Google Maps JavaScript API.
 */

import { SupabaseClient } from '@supabase/supabase-js';

export interface LatLng {
  lat: number;
  lng: number;
}

export interface RouteStep {
  name: string;
  distance_meters: number;
  duration_seconds: number;
  instruction: string;
  modifier?: string;
}

export interface RouteResult {
  ok: boolean;
  provider: string;
  distance_meters: number;
  duration_seconds: number;
  duration_minutes: number;
  polyline: string;
  steps: RouteStep[];
  coordinates?: LatLng[];
}

export interface SnapResult {
  ok: boolean;
  provider: string;
  snapped: {
    lat: number;
    lng: number;
    distance_from_point_m: number;
    street_name: string;
  };
}

export class EvrryWebRoutingClient {
  private supabase: SupabaseClient;

  constructor(supabaseClient: SupabaseClient) {
    this.supabase = supabaseClient;
  }

  /**
   * Calculates driving road route, distance, ETA, and decoded coordinates.
   */
  async getRoute(
    origin: LatLng,
    destination: LatLng,
    waypoints: LatLng[] = [],
    mode: 'driving' | 'motorcycle' | 'walking' = 'driving'
  ): Promise<RouteResult> {
    const { data, error } = await this.supabase.functions.invoke('routing', {
      body: {
        action: 'route',
        origin,
        destination,
        waypoints,
        mode,
      },
    });

    if (error || !data) {
      throw new Error(error?.message || 'Failed to compute route');
    }

    const coordinates = data.polyline ? EvrryWebRoutingClient.decodePolyline(data.polyline) : [];
    return {
      ...data,
      coordinates,
    };
  }

  /**
   * Snaps a coordinate to the nearest road network.
   */
  async snapToRoad(point: LatLng): Promise<SnapResult> {
    const { data, error } = await this.supabase.functions.invoke('routing', {
      body: {
        action: 'nearest',
        point,
      },
    });

    if (error || !data) {
      throw new Error(error?.message || 'Failed to snap point to road');
    }

    return data;
  }

  /**
   * Decodes an OSRM / Google encoded polyline string into an array of LatLng points.
   */
  static decodePolyline(encoded: string): LatLng[] {
    const points: LatLng[] = [];
    let index = 0;
    const len = encoded.length;
    let lat = 0;
    let lng = 0;

    while (index < len) {
      let b: number;
      let shift = 0;
      let result = 0;
      do {
        b = encoded.charCodeAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      const dlat = (result & 1) !== 0 ? ~(result >> 1) : result >> 1;
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.charCodeAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      const dlng = (result & 1) !== 0 ? ~(result >> 1) : result >> 1;
      lng += dlng;

      points.push({ lat: lat / 1e5, lng: lng / 1e5 });
    }
    return points;
  }
}
