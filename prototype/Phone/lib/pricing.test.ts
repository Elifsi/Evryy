import { describe, expect, it } from "vitest";
import { calculateDriverDeliveryEarnings, nightsBetween, priceCart, priceRide, priceStay } from "@/lib/pricing";
import { RideType } from "@/lib/data/rideTypes";

describe("priceCart", () => {
  it("returns all zeros for an empty or all-unknown cart", () => {
    expect(priceCart([])).toEqual({ itemTotal: 0, deliveryFee: 0, platformFee: 0, gst: 0, total: 0 });
    expect(priceCart([{ itemId: "does-not-exist", qty: 1 }])).toEqual({
      itemTotal: 0,
      deliveryFee: 0,
      platformFee: 0,
      gst: 0,
      total: 0,
    });
  });

  it("charges Rs 50 delivery fee + Rs 10 platform fee within 3 km when below Rs 1,000 threshold", () => {
    // food-001 = North Indian Thali, NPR 249 (< 1000 threshold)
    const breakdown = priceCart([{ itemId: "food-001", qty: 1 }], 2.5);
    expect(breakdown.itemTotal).toBe(249);
    expect(breakdown.deliveryFee).toBe(50); // within 3 km
    expect(breakdown.platformFee).toBe(10);
    expect(breakdown.gst).toBe(Math.round(249 * 0.05));
    expect(breakdown.total).toBe(249 + 50 + 10 + Math.round(249 * 0.05));
  });

  it("provides FREE delivery when order exceeds NPR 1,000 threshold", () => {
    // 5x food-001 = 5 * 249 = 1,245 (>= 1,000 free threshold)
    const breakdown = priceCart([{ itemId: "food-001", qty: 5 }], 2.5);
    expect(breakdown.itemTotal).toBe(1245);
    expect(breakdown.deliveryFee).toBe(0); // FREE delivery!
    expect(breakdown.platformFee).toBe(10);
    expect(breakdown.total).toBe(1245 + 0 + 10 + Math.round(1245 * 0.05));
  });

  it("charges extra distance fee of Rs 15 per km beyond 3 km radius", () => {
    // 5 km distance = 3 km base + 2 km extra @ Rs 15 = Rs 50 + Rs 30 = Rs 80
    const breakdown = priceCart([{ itemId: "food-001", qty: 1 }], 5.0);
    expect(breakdown.deliveryFee).toBe(80);
    expect(breakdown.platformFee).toBe(10);
  });

  it("Option A: orders >= Rs 1,000 waive base delivery (Rs 50 free) but pay only extra distance fee beyond 3 km", () => {
    // 5x food-001 = Rs 1,245 (>= 1,000 threshold), at 5 km (2 km extra @ Rs 15 = Rs 30)
    // Base Rs 50 is waived (FREE), so customer pays only Rs 30 delivery fee!
    const breakdown = priceCart([{ itemId: "food-001", qty: 5 }], 5.0);
    expect(breakdown.itemTotal).toBe(1245);
    expect(breakdown.deliveryFee).toBe(30); // 0 base + 30 extra
    expect(breakdown.platformFee).toBe(10);
    expect(breakdown.total).toBe(1245 + 30 + 10 + Math.round(1245 * 0.05));
  });
});


describe("calculateDriverDeliveryEarnings", () => {
  it("pays driver Rs 40 base payout for deliveries within 3 km", () => {
    const earnings = calculateDriverDeliveryEarnings(2.5);
    expect(earnings.basePayout).toBe(40);
    expect(earnings.extraDistanceShare).toBe(0);
    expect(earnings.totalPayout).toBe(40);
  });

  it("pays driver Rs 40 + 80% of extra distance fee beyond 3 km", () => {
    // 5 km distance = 2 extra km * Rs 15 = Rs 30 extra delivery fee
    // Driver gets 80% of Rs 30 = Rs 24 -> Total = 40 + 24 = Rs 64
    const earnings = calculateDriverDeliveryEarnings(5.0);
    expect(earnings.basePayout).toBe(40);
    expect(earnings.extraDistanceShare).toBe(24);
    expect(earnings.totalPayout).toBe(64);
  });
});


describe("nightsBetween", () => {
  it("computes whole nights between two dates", () => {
    expect(nightsBetween("2026-01-01", "2026-01-04")).toBe(3);
  });

  it("clamps to a minimum of 1 night even for a same-day or invalid range", () => {
    expect(nightsBetween("2026-01-01", "2026-01-01")).toBe(1);
    expect(nightsBetween("2026-01-05", "2026-01-01")).toBe(1);
  });
});

describe("priceStay", () => {
  it("computes room total, ~12% taxes and the sum", () => {
    const breakdown = priceStay(2000, 3);
    expect(breakdown.roomTotal).toBe(6000);
    expect(breakdown.taxesAndFees).toBe(Math.round(6000 * 0.12));
    expect(breakdown.total).toBe(breakdown.roomTotal + breakdown.taxesAndFees);
  });
});

describe("priceRide", () => {
  it("computes base fare + rounded per-km distance fare", () => {
    const rideType: RideType = {
      id: "test-ride",
      label: "Test Ride",
      subtitle: "test",
      seats: 4,
      baseFare: 40,
      perKm: 12.5,
      etaMinutes: 3,
    };
    const breakdown = priceRide(rideType, 5);
    expect(breakdown.baseFare).toBe(40);
    expect(breakdown.distanceFare).toBe(Math.round(12.5 * 5));
    expect(breakdown.total).toBe(40 + Math.round(12.5 * 5));
  });
});
