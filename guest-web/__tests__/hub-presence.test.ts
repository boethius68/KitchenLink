/**
 * KL-CLOUD-001: Auswertung der venue_hub_presence-Zeile.
 *
 * Die Regeln sind bewusst konservativ: nur ein eindeutig veralteter
 * Heartbeat MIT gueltiger lokaler URL loest den lokalen Verweis aus.
 * Alles Unklare bleibt beim heutigen, verifizierten Cloud-Verhalten.
 */

import { describe, expect, it } from "vitest";
import {
  evaluateHubPresence,
  HUB_STALE_AFTER_MS,
  sanitizeLocalGuestUrl,
} from "@/lib/hub-presence";

const NOW = Date.parse("2026-07-19T12:00:00.000Z");

function isoAgo(ms: number): string {
  return new Date(NOW - ms).toISOString();
}

describe("evaluateHubPresence", () => {
  it("ist unknown ohne Zeile", () => {
    expect(evaluateHubPresence(null, NOW)).toEqual({ kind: "unknown" });
  });

  it("ist unknown ohne Zeitstempel", () => {
    expect(
      evaluateHubPresence(
        { updated_at: null, local_guest_url: "http://192.168.0.2:8080" },
        NOW,
      ),
    ).toEqual({ kind: "unknown" });
  });

  it("ist unknown bei unparsebarem Zeitstempel", () => {
    expect(
      evaluateHubPresence(
        { updated_at: "kein datum", local_guest_url: "http://192.168.0.2:8080" },
        NOW,
      ),
    ).toEqual({ kind: "unknown" });
  });

  it("ist online bei frischem Heartbeat", () => {
    expect(
      evaluateHubPresence(
        { updated_at: isoAgo(10_000), local_guest_url: "http://192.168.0.2:8080" },
        NOW,
      ),
    ).toEqual({ kind: "online" });
  });

  it("ist online exakt an der Schwelle", () => {
    expect(
      evaluateHubPresence(
        {
          updated_at: isoAgo(HUB_STALE_AFTER_MS),
          local_guest_url: "http://192.168.0.2:8080",
        },
        NOW,
      ),
    ).toEqual({ kind: "online" });
  });

  it("zaehlt leicht zukuenftige Zeitstempel (Uhrendrift) als online", () => {
    expect(
      evaluateHubPresence(
        { updated_at: isoAgo(-5_000), local_guest_url: null },
        NOW,
      ),
    ).toEqual({ kind: "online" });
  });

  it("verweist bei veraltetem Heartbeat auf die lokale URL", () => {
    expect(
      evaluateHubPresence(
        {
          updated_at: isoAgo(HUB_STALE_AFTER_MS + 1_000),
          local_guest_url: "http://192.168.0.2:8080",
        },
        NOW,
      ),
    ).toEqual({
      kind: "local_fallback",
      localGuestUrl: "http://192.168.0.2:8080/",
    });
  });

  it("bleibt unknown bei veraltetem Heartbeat ohne URL (App geschlossen)", () => {
    expect(
      evaluateHubPresence(
        { updated_at: isoAgo(HUB_STALE_AFTER_MS + 1_000), local_guest_url: null },
        NOW,
      ),
    ).toEqual({ kind: "unknown" });
  });

  it("bleibt unknown bei veraltetem Heartbeat mit unbrauchbarer URL", () => {
    expect(
      evaluateHubPresence(
        {
          updated_at: isoAgo(HUB_STALE_AFTER_MS + 1_000),
          local_guest_url: "javascript:alert(1)",
        },
        NOW,
      ),
    ).toEqual({ kind: "unknown" });
  });
});

describe("sanitizeLocalGuestUrl", () => {
  it("akzeptiert http mit Host und Port", () => {
    expect(sanitizeLocalGuestUrl("http://192.168.178.30:52123")).toBe(
      "http://192.168.178.30:52123/",
    );
  });

  it("akzeptiert https", () => {
    expect(sanitizeLocalGuestUrl("https://hub.local/")).toBe(
      "https://hub.local/",
    );
  });

  it("verwirft null, leere und relative Werte", () => {
    expect(sanitizeLocalGuestUrl(null)).toBeNull();
    expect(sanitizeLocalGuestUrl("")).toBeNull();
    expect(sanitizeLocalGuestUrl("/orders")).toBeNull();
  });

  it("verwirft nicht-http(s)-Schemata", () => {
    expect(sanitizeLocalGuestUrl("javascript:alert(1)")).toBeNull();
    expect(sanitizeLocalGuestUrl("file:///etc/hosts")).toBeNull();
    expect(sanitizeLocalGuestUrl("data:text/html,x")).toBeNull();
  });
});
