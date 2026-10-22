import XCTest
@testable import kitchenlink

final class KitchenLinkCashbookTests: XCTestCase {

    func testLoadDemoCashbook() async throws {
        let provider = KitchenLinkCashbookDemoProvider()
        let entries = try await provider.loadCashbook()

        XCTAssertEqual(entries.count, 4)
        // loadCashbook returns sorted descending by entryNumber
        XCTAssertEqual(entries.first?.entryNumber, 4)
        XCTAssertEqual(entries.last?.entryNumber, 1)

        let initial = try XCTUnwrap(entries.first { $0.entryNumber == 1 })
        XCTAssertEqual(initial.entryType, .initialBalance)
        XCTAssertEqual(initial.amountCents, 20000)
        XCTAssertEqual(initial.balanceAfterCents, 20000)
    }

    func testRecordExpenseCalculatesTaxAndReducesBalance() async throws {
        let provider = KitchenLinkCashbookDemoProvider()

        // Initial balance after demo entries was 29460 cents (294.60 €)
        let expense = try await provider.recordExpense(
            amountCents: 5950, // 59.50 € gross with 19% tax = 50.00 € net + 9.50 € (950 cents) tax
            taxRate: 19.0,
            receiptNumber: "BELEG-TEST-01",
            description: "Druckerpapier & Stifte"
        )

        XCTAssertEqual(expense.entryNumber, 5)
        XCTAssertFalse(expense.isIncome)
        XCTAssertEqual(expense.amountCents, 5950)
        XCTAssertEqual(expense.balanceAfterCents, 29460 - 5950)
        XCTAssertEqual(expense.taxCents, 950)
        XCTAssertEqual(expense.receiptNumber, "BELEG-TEST-01")
        XCTAssertEqual(expense.formattedAmount, "-59.50 €")

        let allEntries = try await provider.loadCashbook()
        XCTAssertEqual(allEntries.first?.entryNumber, 5)
    }

    func testRecordDepositIncreasesBalance() async throws {
        let provider = KitchenLinkCashbookDemoProvider()

        let deposit = try await provider.recordDeposit(
            amountCents: 15000,
            description: "Wechselgeldauffrischung"
        )

        XCTAssertEqual(deposit.entryNumber, 5)
        XCTAssertTrue(deposit.isIncome)
        XCTAssertEqual(deposit.amountCents, 15000)
        XCTAssertEqual(deposit.balanceAfterCents, 29460 + 15000)
        XCTAssertEqual(deposit.formattedAmount, "+150.00 €")
    }

    func testTSETransactionSigningAndReceiptFooter() async throws {
        let provider = KitchenLinkCashbookDemoProvider()
        let initialTxs = try await provider.loadTSETransactions()
        XCTAssertEqual(initialTxs.count, 2)

        let signed = try await provider.signTSETransaction(
            amountCents: 3200,
            processType: "Kassenbeleg-V1"
        )

        XCTAssertEqual(signed.transactionNumber, 3)
        XCTAssertEqual(signed.signatureCounter, 3)
        XCTAssertEqual(signed.tseSerial, "TSE-KL-DEMO-001")
        XCTAssertTrue(signed.qrCodeData.contains("TSE-KL-DEMO-001"))
        XCTAssertTrue(signed.qrCodeData.contains("KL-CASH-01;3;"))

        let footer = signed.receiptFooterText
        XCTAssertTrue(footer.contains("TSE-SICHERHEITSBELEG (KassenSichV)"))
        XCTAssertTrue(footer.contains("TSE-Seriennummer: TSE-KL-DEMO-001"))
        XCTAssertTrue(footer.contains("Transaktion: 3 | Zähler: 3"))
    }

    func testCashbookEntryFormatting() {
        let entry = KitchenLinkCashbookEntry(
            entryNumber: 42,
            entryType: .expense,
            amountCents: 2380,
            isIncome: false,
            balanceAfterCents: 18000,
            taxRatePercent: 19.0,
            taxCents: 380,
            receiptNumber: "BON-42",
            description: "Test-Ausgabe"
        )

        XCTAssertEqual(entry.formattedAmount, "-23.80 €")
        XCTAssertEqual(entry.formattedTax, "19% MwSt (3.80 €)")
    }
}
