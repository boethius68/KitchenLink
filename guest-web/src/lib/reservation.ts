/**
 * Reservierungslogik und Datenmodell für das Gast-Web (KL-RES-001, Blueprint §10).
 *
 * Gäste können online einen Tisch anfragen/buchen. Übermittlung erfolgt autoritativ
 * an die RPC `guest_web_create_reservation` in Supabase oder im Offline/Demo-Fall
 * an das deterministische Simulations-Backend.
 */

import type { SupabaseClient } from "@supabase/supabase-js";
import { getSupabase } from "./supabase-client";

export interface ReservationRequest {
  venueSlug: string;
  guestName: string;
  guestEmail: string;
  guestPhone?: string;
  partySize: number;
  reservationDate: string; // YYYY-MM-DD
  reservationTime: string; // HH:MM
  area?: string;
  specialRequests?: string;
}

export interface ReservationResult {
  ok: boolean;
  referenceCode?: string;
  reservationId?: string;
  venueName?: string;
  guestName?: string;
  partySize?: number;
  reservationDate?: string;
  reservationTime?: string;
  status?: string;
  error?: string;
}

export interface ReservationValidation {
  valid: boolean;
  errors: Record<string, string>;
}

/**
 * Validiert die Eingaben für eine Tischreservierung.
 */
export function validateReservationRequest(
  req: Partial<ReservationRequest>,
): ReservationValidation {
  const errors: Record<string, string> = {};

  const name = req.guestName?.trim() ?? "";
  if (name.length < 2) {
    errors.guestName = "Name muss mindestens 2 Zeichen lang sein";
  }

  const email = req.guestEmail?.trim().toLowerCase() ?? "";
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  if (!email || !emailRegex.test(email)) {
    errors.guestEmail = "Ungültige E-Mail-Adresse";
  }

  if (req.guestPhone) {
    const phone = req.guestPhone.trim();
    if (phone.length > 0 && phone.length < 6) {
      errors.guestPhone = "Telefonnummer ist zu kurz (mind. 6 Zeichen)";
    }
  }

  const partySize = req.partySize ?? 0;
  if (!Number.isInteger(partySize) || partySize < 1 || partySize > 20) {
    errors.partySize = "Personenanzahl muss zwischen 1 und 20 liegen";
  }

  const date = req.reservationDate?.trim() ?? "";
  const dateRegex = /^\d{4}-\d{2}-\d{2}$/;
  if (!dateRegex.test(date)) {
    errors.reservationDate = "Datum muss im Format JJJJ-MM-TT vorliegen";
  } else {
    const today = getTodayDateString();
    if (date < today) {
      errors.reservationDate = "Datum darf nicht in der Vergangenheit liegen";
    }
  }

  const time = req.reservationTime?.trim() ?? "";
  const timeRegex = /^\d{2}:\d{2}$/;
  if (!timeRegex.test(time)) {
    errors.reservationTime = "Uhrzeit muss im Format HH:MM vorliegen";
  } else {
    const [hoursStr, minsStr] = time.split(":");
    const hours = parseInt(hoursStr, 10);
    const mins = parseInt(minsStr, 10);
    if (hours < 11 || hours > 23 || mins < 0 || mins > 59) {
      errors.reservationTime = "Uhrzeit muss zwischen 11:00 und 23:00 Uhr liegen";
    }
  }

  return {
    valid: Object.keys(errors).length === 0,
    errors,
  };
}

/**
 * Liefert das heutige Datum im Format YYYY-MM-DD (lokale Zeitzone).
 */
export function getTodayDateString(baseDate = new Date()): string {
  const y = baseDate.getFullYear();
  const m = String(baseDate.getMonth() + 1).padStart(2, "0");
  const d = String(baseDate.getDate()).padStart(2, "0");
  return `${y}-${m}-${d}`;
}

/**
 * Liefert das morgige Datum im Format YYYY-MM-DD.
 */
export function getTomorrowDateString(baseDate = new Date()): string {
  const next = new Date(baseDate);
  next.setDate(next.getDate() + 1);
  return getTodayDateString(next);
}

/**
 * Erzeugt wählbare Zeitslots in 30-Minuten-Intervallen.
 */
export function generateTimeSlots(
  startHour = 12,
  endHour = 22,
  stepMinutes = 30,
): string[] {
  const slots: string[] = [];
  for (let h = startHour; h <= endHour; h++) {
    for (let m = 0; m < 60; m += stepMinutes) {
      if (h === endHour && m > 0) break;
      const hh = String(h).padStart(2, "0");
      const mm = String(m).padStart(2, "0");
      slots.push(`${hh}:${mm}`);
    }
  }
  return slots;
}

/**
 * Formatiert YYYY-MM-DD in lesbares deutsches Datum (z. B. "Fr., 24. Oktober 2026").
 */
export function formatReservationDate(dateStr: string): string {
  try {
    const [y, m, d] = dateStr.split("-").map(Number);
    const dateObj = new Date(y, m - 1, d);
    return dateObj.toLocaleDateString("de-DE", {
      weekday: "short",
      day: "numeric",
      month: "long",
      year: "numeric",
    });
  } catch {
    return dateStr;
  }
}

/**
 * Backend-Schnittstelle für Reservierungen.
 */
export interface ReservationBackend {
  createReservation(request: ReservationRequest): Promise<ReservationResult>;
}

/**
 * Produktiver Aufruf über Supabase RPC.
 */
export class SupabaseReservationBackend implements ReservationBackend {
  constructor(private readonly client: SupabaseClient) {}

  async createReservation(
    request: ReservationRequest,
  ): Promise<ReservationResult> {
    const { data, error } = await this.client.rpc(
      "guest_web_create_reservation",
      {
        p_venue_slug: request.venueSlug,
        p_guest_name: request.guestName.trim(),
        p_guest_email: request.guestEmail.trim().toLowerCase(),
        p_guest_phone: request.guestPhone?.trim() || null,
        p_party_size: request.partySize,
        p_reservation_date: request.reservationDate,
        p_reservation_time: request.reservationTime.length === 5 ? `${request.reservationTime}:00` : request.reservationTime,
        p_area: request.area?.trim() || "",
        p_special_requests: request.specialRequests?.trim() || null,
      },
    );

    if (error) {
      return {
        ok: false,
        error: error.message || "Fehler beim Erstellen der Reservierung",
      };
    }

    if (!data) {
      return { ok: false, error: "Keine Rückmeldung vom Server erhalten" };
    }

    const row = data as Record<string, unknown>;
    return {
      ok: Boolean(row.ok),
      referenceCode:
        (row.reference_code as string | undefined) ??
        (row.referenceCode as string | undefined),
      reservationId:
        (row.reservation_id as string | undefined) ??
        (row.reservationId as string | undefined),
      venueName:
        (row.venue_name as string | undefined) ??
        (row.venueName as string | undefined),
      guestName:
        (row.guest_name as string | undefined) ??
        (row.guestName as string | undefined),
      partySize:
        (row.party_size as number | undefined) ??
        (row.partySize as number | undefined),
      reservationDate:
        (row.reservation_date as string | undefined) ??
        (row.reservationDate as string | undefined),
      reservationTime:
        (row.reservation_time as string | undefined) ??
        (row.reservationTime as string | undefined),
      status: (row.status as string | undefined),
      error: (row.error as string | undefined),
    };
  }
}

/**
 * Lokales Simulations-Backend für Sandbox- & Test-Modus.
 */
export class SimulatedReservationBackend implements ReservationBackend {
  async createReservation(
    request: ReservationRequest,
  ): Promise<ReservationResult> {
    const randCode = Math.floor(100000 + Math.random() * 900000);
    return {
      ok: true,
      referenceCode: `KL-${randCode}`,
      reservationId: `sim-res-${Date.now()}`,
      venueName:
        request.venueSlug === "alte-muehle"
          ? "Gasthof Zur Alten Mühle"
          : request.venueSlug,
      guestName: request.guestName.trim(),
      partySize: request.partySize,
      reservationDate: request.reservationDate,
      reservationTime: request.reservationTime,
      status: "confirmed",
    };
  }
}

/**
 * Fabrikmethode zur Instanziierung des passenden Backends.
 */
export function createDefaultReservationBackend(
  supabase: SupabaseClient | null = getSupabase(),
): ReservationBackend {
  if (supabase) {
    return new SupabaseReservationBackend(supabase);
  }
  return new SimulatedReservationBackend();
}
