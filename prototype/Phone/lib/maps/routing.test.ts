import { describe, expect, it } from "vitest";
import { decodePolyline, encodePolyline } from "./polyline";
import { calculateRoute, haversineMeters } from "./routing";

describe("Polyline Utilities", () => {
  it("encodes and decodes coordinates correctly with zero precision drift", () => {
    const coords = [
      { lat: 27.7172, lng: 85.324 }, // Kathmandu Durbar / Thamel area
      { lat: 27.7007, lng: 85.3001 },
      { lat: 27.671, lng: 85.321 }, // Patan Durbar Square
    ];

    const encoded = encodePolyline(coords);
    expect(typeof encoded).toBe("string");
    expect(encoded.length).toBeGreaterThan(0);

    const decoded = decodePolyline(encoded);
    expect(decoded.length).toBe(coords.length);
    for (let i = 0; i < coords.length; i++) {
      expect(decoded[i].lat).toBeCloseTo(coords[i].lat, 4);
      expect(decoded[i].lng).toBeCloseTo(coords[i].lng, 4);
    }
  });

  it("handles a single coordinate point", () => {
    const coords = [{ lat: 27.71724, lng: 85.32396 }];
    const encoded = encodePolyline(coords);
    const decoded = decodePolyline(encoded);
    expect(decoded.length).toBe(1);
    expect(decoded[0].lat).toBeCloseTo(27.71724, 4);
    expect(decoded[0].lng).toBeCloseTo(85.32396, 4);
  });
});

describe("Routing Service", () => {
  const thamel = { lat: 27.7154, lng: 85.3123 };
  const patan = { lat: 27.6726, lng: 85.3253 };

  it("calculates realistic Haversine distance between Thamel and Patan", () => {
    const distanceMeters = haversineMeters(thamel, patan);
    // Thamel to Patan is roughly 4.8 to 5.2 km crow-flies
    expect(distanceMeters).toBeGreaterThan(4500);
    expect(distanceMeters).toBeLessThan(5500);
  });

  it("computes road route with 1.28 circuity factor, polyline, and ETA", async () => {
    const route = await calculateRoute(thamel, patan);
    expect(route.provider).toBe("circuity_model");
    // Road distance should be ~1.28x crow-flies (~6.2 to 6.8 km)
    expect(route.distanceMeters).toBeGreaterThan(5800);
    expect(route.distanceMeters).toBeLessThan(7200);

    // Urban ETA in minutes (around 15-20 min at 22km/h)
    expect(route.durationMinutes).toBeGreaterThanOrEqual(15);
    expect(route.durationMinutes).toBeLessThanOrEqual(22);

    // Polyline should decode to smooth points including origin and destination
    expect(route.polyline.length).toBeGreaterThan(0);
    expect(route.points.length).toBe(9); // origin + 7 interpolated + destination
    expect(route.points[0].lat).toBeCloseTo(thamel.lat, 4);
    expect(route.points[route.points.length - 1].lat).toBeCloseTo(patan.lat, 4);
  });
});
