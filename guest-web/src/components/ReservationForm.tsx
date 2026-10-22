"use client";

import { useId, useMemo, useState } from "react";
import Link from "next/link";
import {
  createDefaultReservationBackend,
  formatReservationDate,
  generateTimeSlots,
  getTodayDateString,
  getTomorrowDateString,
  validateReservationRequest,
  type ReservationBackend,
  type ReservationRequest,
  type ReservationResult,
} from "@/lib/reservation";
import type { GuestVenue } from "@/lib/venue-data";
import { ThemeToggle } from "./ThemeToggle";

interface ReservationFormProps {
  venue: GuestVenue;
  backend?: ReservationBackend;
}

const COMMON_PARTY_SIZES = [1, 2, 3, 4, 5, 6, 8, 10];
const AVAILABLE_AREAS = [
  { id: "Beliebig", label: "Beliebig (Drinnen oder Draußen)" },
  { id: "Gastraum", label: "Gastraum (Innenbereich)" },
  { id: "Terrasse", label: "Terrasse / Biergarten" },
];

export function ReservationForm({ venue, backend }: ReservationFormProps) {
  const activeBackend = useMemo(
    () => backend ?? createDefaultReservationBackend(),
    [backend],
  );

  const today = useMemo(() => getTodayDateString(), []);
  const tomorrow = useMemo(() => getTomorrowDateString(), []);

  // Form State
  const [partySize, setPartySize] = useState<number>(2);
  const [customPartySize, setCustomPartySize] = useState<string>("");
  const [reservationDate, setReservationDate] = useState<string>(tomorrow);
  const [reservationTime, setReservationTime] = useState<string>("18:30");
  const [area, setArea] = useState<string>("Beliebig");
  const [guestName, setGuestName] = useState<string>("");
  const [guestEmail, setGuestEmail] = useState<string>("");
  const [guestPhone, setGuestPhone] = useState<string>("");
  const [specialRequests, setSpecialRequests] = useState<string>("");

  const [fieldErrors, setFieldErrors] = useState<Record<string, string>>({});
  const [submitError, setSubmitError] = useState<string | null>(null);
  const [isSubmitting, setIsSubmitting] = useState<boolean>(false);
  const [confirmedResult, setConfirmedResult] =
    useState<ReservationResult | null>(null);

  const availableSlots = useMemo(() => generateTimeSlots(12, 22, 30), []);

  const nameId = useId();
  const emailId = useId();
  const phoneId = useId();
  const dateId = useId();
  const requestsId = useId();

  const handlePartySizeSelect = (size: number) => {
    setPartySize(size);
    setCustomPartySize("");
    if (fieldErrors.partySize) {
      setFieldErrors((prev) => {
        const next = { ...prev };
        delete next.partySize;
        return next;
      });
    }
  };

  const handleCustomPartySizeChange = (val: string) => {
    setCustomPartySize(val);
    const parsed = parseInt(val, 10);
    if (!isNaN(parsed) && parsed > 0) {
      setPartySize(parsed);
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setSubmitError(null);

    const payload: ReservationRequest = {
      venueSlug: venue.slug,
      guestName,
      guestEmail,
      guestPhone: guestPhone.trim() || undefined,
      partySize,
      reservationDate,
      reservationTime,
      area: area === "Beliebig" ? "" : area,
      specialRequests: specialRequests.trim() || undefined,
    };

    const validation = validateReservationRequest(payload);
    if (!validation.valid) {
      setFieldErrors(validation.errors);
      return;
    }

    setFieldErrors({});
    setIsSubmitting(true);

    try {
      const result = await activeBackend.createReservation(payload);
      if (result.ok) {
        setConfirmedResult(result);
      } else {
        setSubmitError(
          result.error ?? "Die Reservierung konnte nicht übermittelt werden.",
        );
      }
    } catch (err: unknown) {
      setSubmitError(
        err instanceof Error
          ? err.message
          : "Ein unerwarteter Fehler ist aufgetreten.",
      );
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleReset = () => {
    setConfirmedResult(null);
    setSubmitError(null);
    setGuestName("");
    setGuestEmail("");
    setGuestPhone("");
    setSpecialRequests("");
    setPartySize(2);
    setReservationDate(tomorrow);
    setReservationTime("18:30");
  };

  return (
    <div>
      <header className="kl-venue-header">
        <div className="kl-venue-header-top">
          <div>
            <h1 className="kl-type-display">{venue.name}</h1>
            <p className="kl-venue-header-context kl-type-secondary">
              Tisch online reservieren
            </p>
          </div>
          <div className="kl-venue-header-actions">
            <ThemeToggle />
            <Link
              href={`/${venue.slug}/menu`}
              className="kl-badge kl-badge-on-dark kl-type-meta"
              style={{ textDecoration: "none" }}
            >
              Speisekarte
            </Link>
          </div>
        </div>
      </header>

      <main className="kl-page">
        {confirmedResult ? (
          <section
            className="kl-reservation-card"
            style={{
              marginTop: "var(--kl-space-4)",
              background: "var(--kl-surface-card)",
            }}
            aria-live="polite"
          >
            <div className="kl-confirmation">
              <span className="kl-confirmation-check" aria-hidden="true">
                ✓
              </span>
              <div className="kl-confirmation-body">
                <h2 className="kl-type-section kl-confirmation-title">
                  Reservierung bestätigt!
                </h2>
                <p className="kl-confirmation-meta">
                  Vielen Dank, {confirmedResult.guestName ?? guestName}! Ihr Tisch
                  ist für Sie vorgemerkt.
                </p>
              </div>
            </div>

            <div style={{ textAlign: "center", margin: "var(--kl-space-4) 0" }}>
              <span className="kl-form-label">Ihr Buchungscode</span>
              <div className="kl-reservation-ref-code">
                {confirmedResult.referenceCode}
              </div>
              <p className="kl-form-hint">
                Bitte halten Sie diesen Referenzcode beim Eintreffen bereit.
              </p>
            </div>

            <div
              style={{
                display: "grid",
                gridTemplateColumns: "1fr 1fr",
                gap: "var(--kl-space-3)",
                padding: "var(--kl-space-3)",
                background: "var(--kl-surface-control)",
                borderRadius: "var(--kl-radius-control)",
                marginBottom: "var(--kl-space-4)",
              }}
            >
              <div>
                <span className="kl-form-label" style={{ fontSize: "0.8125rem" }}>
                  Datum
                </span>
                <span className="kl-type-primary">
                  {formatReservationDate(
                    confirmedResult.reservationDate ?? reservationDate,
                  )}
                </span>
              </div>
              <div>
                <span className="kl-form-label" style={{ fontSize: "0.8125rem" }}>
                  Uhrzeit
                </span>
                <span className="kl-type-primary">
                  {confirmedResult.reservationTime ?? reservationTime} Uhr
                </span>
              </div>
              <div>
                <span className="kl-form-label" style={{ fontSize: "0.8125rem" }}>
                  Personen
                </span>
                <span className="kl-type-primary">
                  {confirmedResult.partySize ?? partySize} Gäste
                </span>
              </div>
              <div>
                <span className="kl-form-label" style={{ fontSize: "0.8125rem" }}>
                  Bereich
                </span>
                <span className="kl-type-primary">{area}</span>
              </div>
            </div>

            <div style={{ display: "flex", flexDirection: "column", gap: "var(--kl-space-2)" }}>
              <Link
                href={`/${venue.slug}/menu`}
                className="kl-primary-button kl-type-button"
                style={{
                  display: "flex",
                  alignItems: "center",
                  justifyContent: "center",
                  textDecoration: "none",
                }}
              >
                Zur Speisekarte
              </Link>
              <button
                type="button"
                onClick={handleReset}
                className="kl-secondary-button kl-type-button"
              >
                Weitere Reservierung vornehmen
              </button>
            </div>
          </section>
        ) : (
          <form onSubmit={handleSubmit} noValidate>
            {submitError && (
              <div className="kl-banner-error" role="alert">
                <strong>Reservierung nicht möglich: </strong>
                <span>{submitError}</span>
              </div>
            )}

            {/* 1. Personenanzahl */}
            <div className="kl-reservation-card">
              <label className="kl-form-label">1. Anzahl Personen</label>
              <div className="kl-chips-grid">
                {COMMON_PARTY_SIZES.map((size) => (
                  <button
                    key={size}
                    type="button"
                    className={`kl-chip ${partySize === size && !customPartySize ? "kl-chip-selected" : ""}`}
                    onClick={() => handlePartySizeSelect(size)}
                  >
                    {size} {size === 1 ? "Person" : "Personen"}
                  </button>
                ))}
              </div>
              <div style={{ marginTop: "var(--kl-space-2)" }}>
                <input
                  type="number"
                  min="1"
                  max="20"
                  placeholder="Andere Personenanzahl (1-20)..."
                  value={customPartySize}
                  onChange={(e) => handleCustomPartySizeChange(e.target.value)}
                  className="kl-text-input"
                  style={{ maxWidth: "16rem" }}
                />
              </div>
              {fieldErrors.partySize && (
                <span className="kl-form-error">{fieldErrors.partySize}</span>
              )}
            </div>

            {/* 2. Datum & Uhrzeit */}
            <div className="kl-reservation-card">
              <label htmlFor={dateId} className="kl-form-label">
                2. Datum & Uhrzeit
              </label>

              <div
                className="kl-chips-grid"
                style={{ marginBottom: "var(--kl-space-3)" }}
              >
                <button
                  type="button"
                  className={`kl-chip ${reservationDate === today ? "kl-chip-selected" : ""}`}
                  onClick={() => setReservationDate(today)}
                >
                  Heute
                </button>
                <button
                  type="button"
                  className={`kl-chip ${reservationDate === tomorrow ? "kl-chip-selected" : ""}`}
                  onClick={() => setReservationDate(tomorrow)}
                >
                  Morgen
                </button>
              </div>

              <div className="kl-form-group">
                <input
                  id={dateId}
                  type="date"
                  min={today}
                  value={reservationDate}
                  onChange={(e) => setReservationDate(e.target.value)}
                  className="kl-text-input"
                />
                <span className="kl-form-hint">
                  Ausgewählt: {formatReservationDate(reservationDate)}
                </span>
                {fieldErrors.reservationDate && (
                  <span className="kl-form-error">
                    {fieldErrors.reservationDate}
                  </span>
                )}
              </div>

              <div className="kl-form-group">
                <span
                  className="kl-form-label"
                  style={{ fontSize: "0.875rem", marginBottom: "var(--kl-space-2)" }}
                >
                  Verfügbare Uhrzeiten
                </span>
                <div
                  className="kl-chips-grid"
                  style={{ maxHeight: "9.5rem", overflowY: "auto" }}
                >
                  {availableSlots.map((slot) => (
                    <button
                      key={slot}
                      type="button"
                      className={`kl-chip ${reservationTime === slot ? "kl-chip-selected" : ""}`}
                      onClick={() => setReservationTime(slot)}
                    >
                      {slot}
                    </button>
                  ))}
                </div>
                {fieldErrors.reservationTime && (
                  <span className="kl-form-error">
                    {fieldErrors.reservationTime}
                  </span>
                )}
              </div>
            </div>

            {/* 3. Bereichspräferenz */}
            <div className="kl-reservation-card">
              <label className="kl-form-label">3. Bevorzugter Bereich</label>
              <div className="kl-chips-grid">
                {AVAILABLE_AREAS.map((a) => (
                  <button
                    key={a.id}
                    type="button"
                    className={`kl-chip ${area === a.id ? "kl-chip-selected" : ""}`}
                    onClick={() => setArea(a.id)}
                  >
                    {a.label}
                  </button>
                ))}
              </div>
            </div>

            {/* 4. Kontaktdaten & Anmerkungen */}
            <div className="kl-reservation-card">
              <span className="kl-form-label">4. Kontaktdaten</span>

              <div className="kl-form-group">
                <label htmlFor={nameId} className="kl-form-hint">
                  Vollständiger Name *
                </label>
                <input
                  id={nameId}
                  type="text"
                  required
                  placeholder="z. B. Andrea Sommer"
                  value={guestName}
                  onChange={(e) => setGuestName(e.target.value)}
                  className="kl-text-input"
                />
                {fieldErrors.guestName && (
                  <span className="kl-form-error">{fieldErrors.guestName}</span>
                )}
              </div>

              <div className="kl-form-group">
                <label htmlFor={emailId} className="kl-form-hint">
                  E-Mail-Adresse für Bestätigung *
                </label>
                <input
                  id={emailId}
                  type="email"
                  required
                  placeholder="andrea.sommer@beispiel.de"
                  value={guestEmail}
                  onChange={(e) => setGuestEmail(e.target.value)}
                  className="kl-text-input"
                />
                {fieldErrors.guestEmail && (
                  <span className="kl-form-error">{fieldErrors.guestEmail}</span>
                )}
              </div>

              <div className="kl-form-group">
                <label htmlFor={phoneId} className="kl-form-hint">
                  Telefonnummer (optional für Rückfragen)
                </label>
                <input
                  id={phoneId}
                  type="tel"
                  placeholder="+49 170 1234567"
                  value={guestPhone}
                  onChange={(e) => setGuestPhone(e.target.value)}
                  className="kl-text-input"
                />
                {fieldErrors.guestPhone && (
                  <span className="kl-form-error">{fieldErrors.guestPhone}</span>
                )}
              </div>

              <div className="kl-form-group">
                <label htmlFor={requestsId} className="kl-form-hint">
                  Besondere Anmerkungen & Wünsche (optional)
                </label>
                <textarea
                  id={requestsId}
                  rows={2}
                  placeholder="z. B. Kinderstuhl benötigt, Rollstuhlplatz, Allergien..."
                  value={specialRequests}
                  onChange={(e) => setSpecialRequests(e.target.value)}
                  className="kl-textarea"
                />
              </div>
            </div>

            {/* Absenden */}
            <div style={{ marginTop: "var(--kl-space-4)" }}>
              <button
                type="submit"
                disabled={isSubmitting}
                className="kl-primary-button kl-type-button"
              >
                {isSubmitting
                  ? "Reservierung wird gesendet..."
                  : `Tisch für ${partySize} ${partySize === 1 ? "Gast" : "Gäste"} anfragen`}
              </button>
            </div>
          </form>
        )}

        <p className="kl-trust-signature kl-type-meta">
          Powered by KitchenLink · Vorbestellungen & Tischreservierung
        </p>
      </main>
    </div>
  );
}
