import Testing
import Foundation
@testable import kitchenlink

struct KitchenLinkCSVExporterTests {

    @Test func testEscapeFieldPlain() {
        #expect(KitchenLinkCSVExporter.escapeField("Schnitzel") == "Schnitzel")
        #expect(KitchenLinkCSVExporter.escapeField("12,50") == "\"12,50\"")
        #expect(KitchenLinkCSVExporter.escapeField("Mit \"Zitrone\"") == "\"Mit \"\"Zitrone\"\"\"")
        #expect(KitchenLinkCSVExporter.escapeField("Zeile 1\nZeile 2") == "\"Zeile 1\nZeile 2\"")
    }

    @Test func testFormatCentsDecimal() {
        #expect(KitchenLinkCSVExporter.formatCentsDecimal(0) == "0,00")
        #expect(KitchenLinkCSVExporter.formatCentsDecimal(50) == "0,50")
        #expect(KitchenLinkCSVExporter.formatCentsDecimal(1250) == "12,50")
        #expect(KitchenLinkCSVExporter.formatCentsDecimal(10000) == "100,00")
        #expect(KitchenLinkCSVExporter.formatCentsDecimal(-350) == "-3,50")
    }

    @Test func testExportOrdersCSV() {
        let order1 = KitchenLinkExportOrder(
            id: "ord-001",
            tableNumber: "Tisch 4",
            timestamp: Date(timeIntervalSince1970: 1729600000),
            itemsDescription: "2× Schnitzel Wiener Art, 1× Weißbier",
            subtotalCents: 3850,
            tipCents: 300,
            totalCents: 4150,
            paymentMethod: "Karte"
        )
        let order2 = KitchenLinkExportOrder(
            id: "ord-002",
            tableNumber: "Bar",
            timestamp: Date(timeIntervalSince1970: 1729603600),
            itemsDescription: "1× Espresso",
            subtotalCents: 250,
            tipCents: 50,
            totalCents: 300,
            paymentMethod: "Bar"
        )

        let csv = KitchenLinkCSVExporter.exportOrdersCSV(orders: [order1, order2], includeBOM: false)

        #expect(csv.contains("Bestell-ID,Tisch,Zeitstempel,Artikel,Zwischensumme_EUR,Trinkgeld_EUR,Gesamtsumme_EUR,Zahlungsart"))
        #expect(csv.contains("ord-001,Tisch 4"))
        #expect(csv.contains("\"2× Schnitzel Wiener Art, 1× Weißbier\""))
        #expect(csv.contains("38,50,3,00,41,50,Karte"))
        #expect(csv.contains("ord-002,Bar"))
        #expect(csv.contains("1× Espresso"))
        #expect(csv.contains("2,50,0,50,3,00,Bar"))
    }

    @Test func testExportOrdersCSVIncludesBOM() {
        let csv = KitchenLinkCSVExporter.exportOrdersCSV(orders: [], includeBOM: true)
        #expect(csv.hasPrefix("\u{FEFF}"))
    }

    @Test func testExportShiftSummaryCSV() {
        let shift = KitchenLinkShift(
            id: "shift-777",
            status: "closed",
            openedAt: Date(timeIntervalSince1970: 1729600000),
            closedAt: Date(timeIntervalSince1970: 1729640000),
            zNumber: 42,
            openingCashCents: 15000,
            countedCashCents: 32000,
            expectedCashCents: 32000,
            varianceCents: 0,
            closeNote: "Kassenabschluss fehlerfrei"
        )
        let methodBar = KitchenLinkShiftMethodTotal(method: "Bar", amountCents: 17000, tipCents: 1500, count: 12)
        let methodKarte = KitchenLinkShiftMethodTotal(method: "Karte", amountCents: 25000, tipCents: 2000, count: 18)
        let totals = KitchenLinkShiftTotals(
            revenueCents: 42000,
            tipCents: 3500,
            refundedCents: 0,
            paymentCount: 30,
            refundCount: 0,
            cashPaymentsCents: 17000,
            payoutCents: 0,
            expenseCents: 0,
            depositCents: 0,
            openingCashCents: 15000,
            expectedCashCents: 32000,
            byMethod: [methodBar, methodKarte]
        )

        let csv = KitchenLinkCSVExporter.exportShiftSummaryCSV(shift: shift, totals: totals, includeBOM: false)

        #expect(csv.contains("Schicht-ID,shift-777"))
        #expect(csv.contains("Z-Nummer,42"))
        #expect(csv.contains("Anfangsbestand_EUR,150,00"))
        #expect(csv.contains("Umsatz_EUR,420,00"))
        #expect(csv.contains("Bargeld_Erwartet_EUR,320,00"))
        #expect(csv.contains("Bargeld_Gezaehlt_EUR,320,00"))
        #expect(csv.contains("Zaehldifferenz_EUR,0,00"))
        #expect(csv.contains("Bar,12,170,00,15,00"))
        #expect(csv.contains("Karte,18,250,00,20,00"))
    }
}
