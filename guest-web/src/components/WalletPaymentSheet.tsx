"use client";

import { useState } from "react";
import { formatEuro } from "@/lib/cart";

interface WalletPaymentSheetProps {
  venueName: string;
  tableLabel: string | null;
  totalCents: number;
  isOpen: boolean;
  isSubmitting: boolean;
  onClose: () => void;
  onConfirm: () => void | Promise<void>;
}

export function WalletPayButton({
  onClick,
  disabled,
}: {
  onClick: () => void;
  disabled?: boolean;
}) {
  return (
    <button
      type="button"
      className="kl-wallet-pay-button kl-type-button"
      onClick={onClick}
      disabled={disabled}
      aria-label="Mit Apple Pay oder Google Pay bezahlen"
    >
      <span className="kl-wallet-icon" aria-hidden="true">
        <svg viewBox="0 0 170 170" width="18" height="18" fill="currentColor">
          <path d="M150.37 130.25c-2.45 5.66-5.35 10.87-8.71 15.66-4.58 6.53-8.33 11.05-11.22 13.56-4.48 4.12-9.28 6.23-14.42 6.35-3.69 0-8.14-1.05-13.32-3.18-5.19-2.12-9.97-3.17-14.34-3.17-4.58 0-9.49 1.05-14.75 3.17-5.26 2.13-9.5 3.24-12.74 3.35-4.35.13-9.16-1.9-14.42-6.08-3.69-3.04-7.67-7.81-11.96-14.34-6.42-9.78-11.45-20.98-15.09-33.59-3.64-12.61-5.46-24.68-5.46-36.21 0-14.78 3.59-27.17 10.77-37.16 7.18-9.99 16.32-15.09 27.42-15.29 4.35 0 9.29 1.15 14.82 3.46 5.53 2.31 9.35 3.53 11.46 3.66 1.48 0 5.61-1.32 12.39-3.96 6.78-2.64 12.33-3.83 16.65-3.56 12.83.66 22.95 5.48 30.36 14.46-11.19 6.8-16.65 16.34-16.39 28.62.26 9.68 3.99 17.84 11.19 24.48 7.2 6.64 15.82 10.42 25.86 11.35-2.09 6.42-4.66 12.87-7.71 19.34zM119.22 31.84c0-7.39 2.65-14.54 7.95-21.46 5.3-6.92 11.92-11.23 19.86-12.92.53 1.32.79 2.7.79 4.15 0 7.39-2.75 14.65-8.25 21.78-5.5 7.13-12.13 11.39-19.89 12.79-.13-1.45-.46-2.89-.46-4.34z"/>
        </svg>
      </span>
      <span>Pay mit Wallet</span>
    </button>
  );
}

export function WalletPaymentSheet({
  venueName,
  tableLabel,
  totalCents,
  isOpen,
  isSubmitting,
  onClose,
  onConfirm,
}: WalletPaymentSheetProps) {
  const [isAuthorizing, setIsAuthorizing] = useState(false);

  if (!isOpen) return null;

  const handleClose = () => {
    setIsAuthorizing(false);
    onClose();
  };

  const handleAuthorize = async () => {
    setIsAuthorizing(true);
    // Haptic feedback simulation if supported
    if (typeof navigator !== "undefined" && "vibrate" in navigator) {
      try {
        navigator.vibrate([20, 40, 20]);
      } catch {
        // Ignore vibration errors
      }
    }
    // Brief realistic delay for Face ID / Passcode prompt simulation
    setTimeout(async () => {
      setIsAuthorizing(false);
      await onConfirm();
    }, 600);
  };

  return (
    <div className="kl-sheet-backdrop" onClick={handleClose}>
      <div
        className="kl-wallet-modal"
        role="dialog"
        aria-modal="true"
        aria-labelledby="kl-wallet-modal-title"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="kl-wallet-modal-handle" />

        <div className="kl-wallet-modal-header">
          <span className="kl-wallet-badge">Sandbox Wallet</span>
          <h3 id="kl-wallet-modal-title" className="kl-type-section">
            Mobiles Bezahlen
          </h3>
          <p className="kl-type-secondary">
            Simulierte Zahlung via Apple Pay / Google Pay
          </p>
        </div>

        <div className="kl-wallet-card-preview">
          <div className="kl-wallet-card-icon">💳</div>
          <div className="kl-wallet-card-info">
            <p className="kl-type-primary">KitchenLink Debit Card</p>
            <p className="kl-type-meta">•••• 4242 · Sandbox Guthaben</p>
          </div>
          <span className="kl-badge kl-badge-on-light kl-type-meta">Bereit</span>
        </div>

        <div className="kl-wallet-details">
          <div className="kl-wallet-detail-row">
            <span className="kl-type-secondary">Händler</span>
            <span className="kl-type-primary">{venueName}</span>
          </div>
          {tableLabel && (
            <div className="kl-wallet-detail-row">
              <span className="kl-type-secondary">Tisch</span>
              <span className="kl-type-primary">{tableLabel}</span>
            </div>
          )}
          <div className="kl-wallet-detail-row kl-wallet-total-row">
            <span className="kl-type-primary">Gesamtbetrag</span>
            <span className="kl-type-display kl-tabular">{formatEuro(totalCents)}</span>
          </div>
        </div>

        <div className="kl-wallet-actions">
          <button
            type="button"
            className="kl-wallet-confirm-button kl-type-button"
            onClick={handleAuthorize}
            disabled={isAuthorizing || isSubmitting}
          >
            {isAuthorizing || isSubmitting ? (
              <span className="kl-wallet-spinner" aria-hidden="true" />
            ) : (
              <span>Mit Face ID / PIN bestätigen</span>
            )}
          </button>
          <button
            type="button"
            className="kl-secondary-button kl-type-button"
            onClick={handleClose}
            disabled={isAuthorizing || isSubmitting}
          >
            Abbrechen
          </button>
        </div>
      </div>
    </div>
  );
}
