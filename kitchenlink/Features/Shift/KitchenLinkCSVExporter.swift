import Foundation

/// Datenmodell für eine exportierbare Bestellung im CSV-Bericht.
struct KitchenLinkExportOrder: Identifiable, Equatable, Sendable {
    let id: String
    let tableNumber: String
    let timestamp: Date
    let itemsDescription: String
    let subtotalCents: Int
    let tipCents: Int
    let totalCents: Int
    let paymentMethod: String
}

/// Dienstprogramm zum RFC-4180-konformen CSV-Export von Bestellungen und Schichtberichten.
enum KitchenLinkCSVExporter {
    private static let isoDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let germanDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    /// Maskiert ein Textfeld nach RFC 4180:
    /// Enthält das Feld Kommas, Anführungszeichen oder Zeilenumbrüche, wird es in doppelte
    /// Anführungszeichen gesetzt und innere Anführungszeichen werden verdoppelt.
    static func escapeField(_ value: String) -> String {
        if value.contains("\"") || value.contains(",") || value.contains("\n") || value.contains("\r") {
            let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return value
    }

    /// Formatiert Cent-Beträge als Dezimal-Eurostring (z. B. 1250 -> "12,50").
    static func formatCentsDecimal(_ cents: Int) -> String {
        let sign = cents < 0 ? "-" : ""
        let absolute = abs(cents)
        let euros = absolute / 100
        let fraction = absolute % 100
        return "\(sign)\(euros),\(String(format: "%02d", fraction))"
    }

    /// Exportiert Bestellungen als RFC-4180-konforme CSV-Zeilen (inkl. UTF-8 BOM für Excel).
    static func exportOrdersCSV(
        orders: [KitchenLinkExportOrder],
        includeBOM: Bool = true
    ) -> String {
        var lines: [String] = []

        // UTF-8 BOM, damit Microsoft Excel Umlaute ohne Import-Dialog automatisch korrekt darstellt
        let prefix = includeBOM ? "\u{FEFF}" : ""

        // RFC 4180 Header
        let header = [
            "Bestell-ID",
            "Tisch",
            "Zeitstempel",
            "Artikel",
            "Zwischensumme_EUR",
            "Trinkgeld_EUR",
            "Gesamtsumme_EUR",
            "Zahlungsart"
        ].map(escapeField).joined(separator: ",")
        lines.append(header)

        for order in orders {
            let row = [
                order.id,
                order.tableNumber,
                germanDateFormatter.string(from: order.timestamp),
                order.itemsDescription,
                formatCentsDecimal(order.subtotalCents),
                formatCentsDecimal(order.tipCents),
                formatCentsDecimal(order.totalCents),
                order.paymentMethod
            ].map(escapeField).joined(separator: ",")
            lines.append(row)
        }

        return prefix + lines.joined(separator: "\r\n") + "\r\n"
    }

    /// Exportiert eine Schicht- und Kassenabschlusszusammenfassung als CSV.
    static func exportShiftSummaryCSV(
        shift: KitchenLinkShift?,
        totals: KitchenLinkShiftTotals,
        includeBOM: Bool = true
    ) -> String {
        var lines: [String] = []
        let prefix = includeBOM ? "\u{FEFF}" : ""

        // Schicht-Kopfdaten
        lines.append(["Kennzahl", "Wert"].map(escapeField).joined(separator: ","))
        lines.append(["Schicht-ID", shift?.id ?? "keine"].map(escapeField).joined(separator: ","))
        lines.append(["Status", shift?.status ?? "geschlossen"].map(escapeField).joined(separator: ","))

        if let zNumber = shift?.zNumber {
            lines.append(["Z-Nummer", String(zNumber)].map(escapeField).joined(separator: ","))
        }
        if let openedAt = shift?.openedAt {
            lines.append(["Geoeffnet", germanDateFormatter.string(from: openedAt)].map(escapeField).joined(separator: ","))
        }
        if let closedAt = shift?.closedAt {
            lines.append(["Geschlossen", germanDateFormatter.string(from: closedAt)].map(escapeField).joined(separator: ","))
        }

        lines.append(["Anfangsbestand_EUR", formatCentsDecimal(totals.openingCashCents)].map(escapeField).joined(separator: ","))
        lines.append(["Umsatz_EUR", formatCentsDecimal(totals.revenueCents)].map(escapeField).joined(separator: ","))
        lines.append(["Trinkgeld_EUR", formatCentsDecimal(totals.tipCents)].map(escapeField).joined(separator: ","))
        lines.append(["Rueckzahlungen_EUR", formatCentsDecimal(totals.refundedCents)].map(escapeField).joined(separator: ","))
        lines.append(["Bargeldeinzahlungen_EUR", formatCentsDecimal(totals.depositCents)].map(escapeField).joined(separator: ","))
        lines.append(["Bargeldauszahlungen_EUR", formatCentsDecimal(totals.payoutCents)].map(escapeField).joined(separator: ","))
        lines.append(["Bargeldausgaben_EUR", formatCentsDecimal(totals.expenseCents)].map(escapeField).joined(separator: ","))
        lines.append(["Bargeld_Erwartet_EUR", formatCentsDecimal(totals.expectedCashCents)].map(escapeField).joined(separator: ","))

        if let counted = shift?.countedCashCents {
            lines.append(["Bargeld_Gezaehlt_EUR", formatCentsDecimal(counted)].map(escapeField).joined(separator: ","))
        }
        if let diff = shift?.varianceCents {
            lines.append(["Zaehldifferenz_EUR", formatCentsDecimal(diff)].map(escapeField).joined(separator: ","))
        }

        // Leerzeile und Zahlungsarten-Aufschlüsselung
        lines.append("")
        lines.append(["Zahlungsart", "Anzahl", "Umsatz_EUR", "Trinkgeld_EUR"].map(escapeField).joined(separator: ","))
        for method in totals.byMethod {
            lines.append([
                method.method,
                String(method.count),
                formatCentsDecimal(method.amountCents),
                formatCentsDecimal(method.tipCents)
            ].map(escapeField).joined(separator: ","))
        }

        return prefix + lines.joined(separator: "\r\n") + "\r\n"
    }
}
