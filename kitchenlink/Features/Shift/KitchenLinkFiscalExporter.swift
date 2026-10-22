import Foundation

/// KL-FISCAL-001: DATEV- & DSFinV-K-Testexport für Kassenprüfung und Buchhaltung (Blueprint §15 & Meilenstein 6).
///
/// Erzeugt standardkonforme DATEV-Buchungsstapel (Formatversion 700 / EXTF)
/// und DSFinV-K-konforme Kassenprüfdaten für unangekündigte Kassen-Nachschauen
/// nach § 146b AO und GoBD.
public enum KitchenLinkFiscalExporter {

    private static let germanDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "ddMM"
        return formatter
    }()

    private static let isoDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    /// Erzeugt einen DATEV-konformen Buchungsstapel (EXTF-Format 700 mit Semikolon-Trennung).
    ///
    /// Standardkontenrahmen SKR03:
    /// - 1000: Kasse
    /// - 8400: Erlöse 19 % USt
    /// - 8300: Erlöse 7 % USt
    /// - 4900: Sonstige betriebliche Aufwendungen / Betriebsausgaben
    /// - 1360: Geldtransit / Privateinlagen
    public static func exportDATEVBuchungsstapel(
        entries: [KitchenLinkCashbookEntry],
        beraterNummer: Int = 10001,
        mandantenNummer: Int = 99999
    ) -> String {
        var lines: [String] = []

        let now = Date()
        let calendar = Calendar.current
        let year = calendar.component(.year, from: now)
        let creationTimestamp = DateFormatter.localizedString(from: now, dateStyle: .short, timeStyle: .medium)
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: ".", with: "")

        // DATEV Header Zeile 1 (Kopfdaten nach EXTF-Spezifikation 700)
        let headerZeile1 = "\"EXTF\";700;21;\"Buchungsstapel\";1;\"\(creationTimestamp)\";\"KitchenLink\";\"\";\"RE\";\"\";\(beraterNummer);\(mandantenNummer);\(year)0101;4;\"\(year)0101\";\"\(year)1231\";\"KitchenLink Kassenbuch\";\"\";1;0;0;\"EUR\";\"\";\"\";\"\";\"\";\"\";\"\";\"\";\"\";\"\";\"\";\"\""
        lines.append(headerZeile1)

        // DATEV Header Zeile 2 (Feldbezeichner)
        let headerZeile2 = "Umsatz (ohne Soll/Haben-Kz);Soll/Haben-Kennzeichen;WKZ;Kurs;Basis-Umsatz;WKZ Basis-Umsatz;Konto;Gegenkonto (ohne BU-Schlüssel);BU-Schlüssel;Belegdatum;Belegfeld 1;Belegfeld 2;Skonto;Buchungstext"
        lines.append(headerZeile2)

        for entry in entries.sorted(by: { $0.entryNumber < $1.entryNumber }) {
            let amountStr = String(format: "%.2f", Double(entry.amountCents) / 100.0).replacingOccurrences(of: ".", with: ",")
            let sollHaben = entry.isIncome ? "S" : "H"
            let belegdatum = germanDateFormatter.string(from: entry.bookingDate)
            let belegnummer = entry.receiptNumber ?? "KL-\(entry.entryNumber)"

            var konto = "8400"
            var buSchluessel = ""

            switch entry.entryType {
            case .cashSale:
                if let rate = entry.taxRatePercent, rate == 7.0 {
                    konto = "8300"
                    buSchluessel = "2" // DATEV Steuerschlüssel 7%
                } else {
                    konto = "8400"
                    buSchluessel = "3" // DATEV Steuerschlüssel 19%
                }
            case .expense:
                konto = "4900" // Sonstiger Betriebsaufwand
                buSchluessel = entry.taxRatePercent == 7.0 ? "2" : (entry.taxRatePercent == 19.0 ? "3" : "")
            case .initialBalance, .deposit:
                konto = "1360" // Geldtransit
            case .payout, .cashRefund, .closingVariance:
                konto = "1360"
            }

            let gegenkonto = "1000" // Kassenkonto
            let buchungstext = entry.description.replacingOccurrences(of: ";", with: " ")

            let row = "\(amountStr);\(sollHaben);EUR;;;;\(konto);\(gegenkonto);\(buSchluessel);\(belegdatum);\(belegnummer);;;\"\(buchungstext)\""
            lines.append(row)
        }

        return lines.joined(separator: "\r\n") + "\r\n"
    }

    /// Erzeugt einen DSFinV-K-konformen Prüfexport für Finanzamts-Kassen-Nachschauen (§ 146b AO).
    public static func exportDSFinVK(
        entries: [KitchenLinkCashbookEntry],
        tseTransactions: [KitchenLinkTSETransaction],
        tseSerial: String = "TSE-KL-DEMO-001"
    ) -> String {
        var lines: [String] = []

        lines.append("# DSFinV-K KASSENPRUEFEXPORT V2.3 (GoBD / KassenSichV)")
        lines.append("# Erstellt am: \(isoDateFormatter.string(from: Date()))")
        lines.append("# TSE-Seriennummer: \(tseSerial)")
        lines.append("# System: KitchenLink Restaurant OS (Sandbox-Beta)")
        lines.append("")

        // Sektion 1: Kassenstamm & TSE
        lines.append("[TSE_STAMMDATEN]")
        lines.append("TSE_ID;TSE_SERIAL;ALGORITHMUS;STATUS;LETZTER_ZAEHLER")
        let maxSigCounter = tseTransactions.map(\.signatureCounter).max() ?? 0
        lines.append("1;\(tseSerial);ECDSA-plain-SHA256;IN_BETRIEB;\(maxSigCounter)")
        lines.append("")

        // Sektion 2: Transaktionen und TSE-Signaturen
        lines.append("[TRANSAKTIONEN]")
        lines.append("BON_NR;TX_NR;START;ENDE;TYP;BRUTTO_EUR;TSE_SIG_COUNTER;TSE_SIGNATUR;DSFINVK_QR")
        for tx in tseTransactions.sorted(by: { $0.transactionNumber < $1.transactionNumber }) {
            let start = isoDateFormatter.string(from: tx.startedAt)
            let ende = isoDateFormatter.string(from: tx.finishedAt)
            lines.append("\(tx.transactionNumber);\(tx.transactionNumber);\(start);\(ende);\(tx.processType);0,00;\(tx.signatureCounter);\(tx.signatureValue);\(tx.qrCodeData)")
        }
        lines.append("")

        // Sektion 3: Kassenbuch-Guthaben & Einzelbewegungen
        lines.append("[KASSENBUCH_BEWEGUNGEN]")
        lines.append("LFD_NR;ZEIT;TYP;EINNAHME;BETRAG_EUR;MWST_SATZ;MWST_EUR;SALDO_EUR;BELEG;TEXT")
        for entry in entries.sorted(by: { $0.entryNumber < $1.entryNumber }) {
            let zeit = isoDateFormatter.string(from: entry.bookingDate)
            let betrag = String(format: "%.2f", Double(entry.amountCents) / 100.0).replacingOccurrences(of: ".", with: ",")
            let mwstSatz = entry.taxRatePercent.map { "\($0)%" } ?? "0%"
            let mwstEur = String(format: "%.2f", Double(entry.taxCents) / 100.0).replacingOccurrences(of: ".", with: ",")
            let saldo = String(format: "%.2f", Double(entry.balanceAfterCents) / 100.0).replacingOccurrences(of: ".", with: ",")
            let beleg = entry.receiptNumber ?? ""
            let text = entry.description.replacingOccurrences(of: ";", with: " ")
            let einnahme = entry.isIncome ? "1" : "0"

            lines.append("\(entry.entryNumber);\(zeit);\(entry.entryType.rawValue);\(einnahme);\(betrag);\(mwstSatz);\(mwstEur);\(saldo);\(beleg);\"\(text)\"")
        }

        return lines.joined(separator: "\r\n") + "\r\n"
    }
}
