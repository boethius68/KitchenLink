import { describe, expect, it, vi } from "vitest";
import {
  formatReservationDate,
  generateTimeSlots,
  getTodayDateString,
  getTomorrowDateString,
  SimulatedReservationBackend,
  SupabaseReservationBackend,
  validateReservationRequest,
  type ReservationRequest,
} from "../src/lib/reservation";
import type { SupabaseClient } from "@supabase/supabase-js";

describe("Reservation domain & validation", () => {
  const validRequest: ReservationRequest = {
    venueSlug: "alte-muehle",
    guestName: "Maximilian Mustermann",
    guestEmail: "max@example.com",
    guestPhone: "+491701234567",
    partySize: 4,
    reservationDate: getTomorrowDateString(),
    reservationTime: "18:30",
    area: "Gastraum",
    specialRequests: "Kinderstuhl bitte",
  };

  it("validates a complete, valid reservation request", () => {
    const res = validateReservationRequest(validRequest);
    expect(res.valid).toBe(true);
    expect(Object.keys(res.errors)).toHaveLength(0);
  });

  it("rejects names with fewer than 2 characters", () => {
    const res = validateReservationRequest({ ...validRequest, guestName: "M" });
    expect(res.valid).toBe(false);
    expect(res.errors.guestName).toContain("mindestens 2 Zeichen");
  });

  it("rejects invalid email formats", () => {
    const res = validateReservationRequest({
      ...validRequest,
      guestEmail: "invalid-email-at-test",
    });
    expect(res.valid).toBe(false);
    expect(res.errors.guestEmail).toContain("Ungültige E-Mail");
  });

  it("rejects party size less than 1 or greater than 20", () => {
    const resZero = validateReservationRequest({ ...validRequest, partySize: 0 });
    expect(resZero.valid).toBe(false);
    expect(resZero.errors.partySize).toBeDefined();

    const resTooLarge = validateReservationRequest({ ...validRequest, partySize: 25 });
    expect(resTooLarge.valid).toBe(false);
    expect(resTooLarge.errors.partySize).toBeDefined();
  });

  it("rejects dates in the past", () => {
    const res = validateReservationRequest({
      ...validRequest,
      reservationDate: "2020-01-01",
    });
    expect(res.valid).toBe(false);
    expect(res.errors.reservationDate).toContain("Vergangenheit");
  });

  it("rejects times outside of opening window 11:00 - 23:00", () => {
    const resEarly = validateReservationRequest({
      ...validRequest,
      reservationTime: "08:00",
    });
    expect(resEarly.valid).toBe(false);
    expect(resEarly.errors.reservationTime).toBeDefined();

    const resMalformed = validateReservationRequest({
      ...validRequest,
      reservationTime: "25:00",
    });
    expect(resMalformed.valid).toBe(false);
  });

  it("validates optional phone number length if provided", () => {
    const resShortPhone = validateReservationRequest({
      ...validRequest,
      guestPhone: "123",
    });
    expect(resShortPhone.valid).toBe(false);
    expect(resShortPhone.errors.guestPhone).toContain("zu kurz");

    const resNoPhone = validateReservationRequest({
      ...validRequest,
      guestPhone: undefined,
    });
    expect(resNoPhone.valid).toBe(true);
  });

  it("generates 30-minute time slots correctly", () => {
    const slots = generateTimeSlots(17, 19, 30);
    expect(slots).toEqual(["17:00", "17:30", "18:00", "18:30", "19:00"]);
  });

  it("formats date strings in German readable format", () => {
    expect(getTodayDateString()).toMatch(/^\d{4}-\d{2}-\d{2}$/);
    const formatted = formatReservationDate("2026-10-24");
    expect(formatted).toMatch(/24\.\s+Oktober\s+2026/);
  });

  it("creates a simulated reservation with valid reference code", async () => {
    const backend = new SimulatedReservationBackend();
    const result = await backend.createReservation(validRequest);
    expect(result.ok).toBe(true);
    expect(result.referenceCode).toMatch(/^KL-\d{6}$/);
    expect(result.guestName).toBe("Maximilian Mustermann");
    expect(result.partySize).toBe(4);
    expect(result.status).toBe("confirmed");
  });

  it("handles Supabase RPC successful execution", async () => {
    const mockRpc = vi.fn().mockResolvedValue({
      data: {
        ok: true,
        reference_code: "KL-998877",
        reservation_id: "uuid-123",
        venue_name: "Gasthof Zur Alten Mühle",
        guest_name: "Maximilian Mustermann",
        party_size: 4,
        reservation_date: "2026-10-24",
        reservation_time: "18:30:00",
        status: "confirmed",
      },
      error: null,
    });

    const client = { rpc: mockRpc } as unknown as SupabaseClient;
    const backend = new SupabaseReservationBackend(client);

    const result = await backend.createReservation(validRequest);
    expect(mockRpc).toHaveBeenCalledWith("guest_web_create_reservation", {
      p_venue_slug: "alte-muehle",
      p_guest_name: "Maximilian Mustermann",
      p_guest_email: "max@example.com",
      p_guest_phone: "+491701234567",
      p_party_size: 4,
      p_reservation_date: validRequest.reservationDate,
      p_reservation_time: "18:30:00",
      p_area: "Gastraum",
      p_special_requests: "Kinderstuhl bitte",
    });

    expect(result.ok).toBe(true);
    expect(result.referenceCode).toBe("KL-998877");
  });

  it("handles Supabase RPC errors gracefully", async () => {
    const mockRpc = vi.fn().mockResolvedValue({
      data: null,
      error: { message: "Database connection failed" },
    });

    const client = { rpc: mockRpc } as unknown as SupabaseClient;
    const backend = new SupabaseReservationBackend(client);

    const result = await backend.createReservation(validRequest);
    expect(result.ok).toBe(false);
    expect(result.error).toBe("Database connection failed");
  });
});
