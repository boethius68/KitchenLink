import Foundation

/// KL-CASHBOOK-001 & KL-TSE-001: Kassenbuch & TSE-Simulation (Blueprint §15 & Meilenstein 6).
///
/// Lückenloses GoBD-konformes Kassenbuch und KassenSichV-konforme
/// TSE-Signierung für die Abrechnungssandbox.

public enum KitchenLinkCashbookEntryType: String, CaseIterable, Identifiable, Sendable {
    case initialBalance = "initial_balance"
    case cashSale = "cash_sale"
    case cashRefund = "cash_refund"
    case expense = "expense"
    case deposit = "deposit"
    case payout = "payout"
    case closingVariance = "closing_variance"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .initialBalance: return "Anfangsbestand"
        case .cashSale: return "Barverkauf"
        case .cashRefund: return "Rückzahlung / Storno"
        case .expense: return "Betriebsausgabe"
        case .deposit: return "Geldeinlage"
        case .payout: return "Geldentnahme"
        case .closingVariance: return "Kassendifferenz"
        }
    }

    public var icon: String {
        switch self {
        case .initialBalance: return "banknote"
        case .cashSale: return "arrow.down.left"
        case .cashRefund: return "arrow.uturn.backward"
        case .expense: return "cart.badge.minus"
        case .deposit: return "plus.circle"
        case .payout: return "arrow.up.right"
        case .closingVariance: return "exclamationmark.triangle"
        }
    }
}

public struct KitchenLinkCashbookEntry: Identifiable, Equatable, Sendable {
    public let id: String
    public var entryNumber: Int
    public var bookingDate: Date
    public var entryType: KitchenLinkCashbookEntryType
    public var amountCents: Int
    public var isIncome: Bool
    public var balanceAfterCents: Int
    public var taxRatePercent: Decimal?
    public var taxCents: Int
    public var receiptNumber: String?
    public var description: String

    public init(
        id: String = UUID().uuidString,
        entryNumber: Int,
        bookingDate: Date = Date(),
        entryType: KitchenLinkCashbookEntryType,
        amountCents: Int,
        isIncome: Bool,
        balanceAfterCents: Int,
        taxRatePercent: Decimal? = nil,
        taxCents: Int = 0,
        receiptNumber: String? = nil,
        description: String
    ) {
        self.id = id
        self.entryNumber = entryNumber
        self.bookingDate = bookingDate
        self.entryType = entryType
        self.amountCents = amountCents
        self.isIncome = isIncome
        self.balanceAfterCents = balanceAfterCents
        self.taxRatePercent = taxRatePercent
        self.taxCents = taxCents
        self.receiptNumber = receiptNumber
        self.description = description
    }

    public var formattedAmount: String {
        let euros = Double(amountCents) / 100.0
        let sign = isIncome ? "+" : "-"
        return String(format: "%@%.2f €", sign, euros)
    }

    public var formattedBalance: String {
        let euros = Double(balanceAfterCents) / 100.0
        return String(format: "%.2f €", locale: Locale(identifier: "de_DE"), euros)
    }

    public var formattedTax: String? {
        guard let rate = taxRatePercent, rate > 0 else { return nil }
        let euros = Double(taxCents) / 100.0
        return String(format: "%.0f%% MwSt (%.2f €)", (rate as NSDecimalNumber).doubleValue, euros)
    }
}

public struct KitchenLinkTSETransaction: Identifiable, Equatable, Sendable {
    public let id: String
    public var tseSerial: String
    public var transactionNumber: Int
    public var signatureCounter: Int
    public var startedAt: Date
    public var finishedAt: Date
    public var processType: String
    public var signatureValue: String
    public var qrCodeData: String

    public init(
        id: String = UUID().uuidString,
        tseSerial: String = "TSE-KL-DEMO-001",
        transactionNumber: Int,
        signatureCounter: Int,
        startedAt: Date = Date().addingTimeInterval(-3),
        finishedAt: Date = Date(),
        processType: String = "Kassenbeleg-V1",
        signatureValue: String,
        qrCodeData: String
    ) {
        self.id = id
        self.tseSerial = tseSerial
        self.transactionNumber = transactionNumber
        self.signatureCounter = signatureCounter
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.processType = processType
        self.signatureValue = signatureValue
        self.qrCodeData = qrCodeData
    }

    public var receiptFooterText: String {
        """
        --- TSE-SICHERHEITSBELEG (KassenSichV) ---
        TSE-Seriennummer: \(tseSerial)
        Transaktion: \(transactionNumber) | Zähler: \(signatureCounter)
        Start: \(KitchenLinkReservationDateHelper.formatTime(startedAt)) Uhr
        Ende:  \(KitchenLinkReservationDateHelper.formatTime(finishedAt)) Uhr
        Signatur: \(signatureValue.prefix(28))...
        """
    }
}

public protocol KitchenLinkCashbookProviding: Sendable {
    func loadCashbook() async throws -> [KitchenLinkCashbookEntry]
    func recordExpense(
        amountCents: Int,
        taxRate: Decimal?,
        receiptNumber: String?,
        description: String
    ) async throws -> KitchenLinkCashbookEntry
    func recordDeposit(amountCents: Int, description: String) async throws -> KitchenLinkCashbookEntry
    func loadTSETransactions() async throws -> [KitchenLinkTSETransaction]
    func signTSETransaction(amountCents: Int, processType: String) async throws -> KitchenLinkTSETransaction
}

public actor KitchenLinkCashbookDemoProvider: KitchenLinkCashbookProviding {
    private var entries: [KitchenLinkCashbookEntry]
    private var tseTransactions: [KitchenLinkTSETransaction]

    public init() {
        let now = Date()
        self.entries = [
            KitchenLinkCashbookEntry(
                entryNumber: 1,
                bookingDate: now.addingTimeInterval(-8 * 3600),
                entryType: .initialBalance,
                amountCents: 20000,
                isIncome: true,
                balanceAfterCents: 20000,
                receiptNumber: "BELEG-001",
                description: "Kassenanfangsbestand Wechselgeld"
            ),
            KitchenLinkCashbookEntry(
                entryNumber: 2,
                bookingDate: now.addingTimeInterval(-6 * 3600),
                entryType: .cashSale,
                amountCents: 4850,
                isIncome: true,
                balanceAfterCents: 24850,
                taxRatePercent: 7.00,
                taxCents: 317,
                receiptNumber: "BON-101",
                description: "Barzahlung Tisch 2 (Speisen)"
            ),
            KitchenLinkCashbookEntry(
                entryNumber: 3,
                bookingDate: now.addingTimeInterval(-4 * 3600),
                entryType: .expense,
                amountCents: 1890,
                isIncome: false,
                balanceAfterCents: 22960,
                taxRatePercent: 19.00,
                taxCents: 302,
                receiptNumber: "BELEG-002",
                description: "Bürobedarf Bonrollen & Schreibblöcke"
            ),
            KitchenLinkCashbookEntry(
                entryNumber: 4,
                bookingDate: now.addingTimeInterval(-2 * 3600),
                entryType: .cashSale,
                amountCents: 6500,
                isIncome: true,
                balanceAfterCents: 29460,
                taxRatePercent: 19.00,
                taxCents: 1038,
                receiptNumber: "BON-102",
                description: "Barzahlung Theke (Getränke)"
            )
        ]

        self.tseTransactions = [
            KitchenLinkTSETransaction(
                transactionNumber: 1,
                signatureCounter: 1,
                startedAt: now.addingTimeInterval(-6 * 3600 - 5),
                finishedAt: now.addingTimeInterval(-6 * 3600),
                processType: "Kassenbeleg-V1",
                signatureValue: "MEYCIQDn2Wd3aY+78sX8Z3g/7Lw9r21eT==",
                qrCodeData: "V0;KL-CASH-01;1;2026-10-23T12:00:00Z;2026-10-23T12:00:05Z;1;MEYCIQDn2Wd3aY;TSE-KL-DEMO-001"
            ),
            KitchenLinkTSETransaction(
                transactionNumber: 2,
                signatureCounter: 2,
                startedAt: now.addingTimeInterval(-2 * 3600 - 4),
                finishedAt: now.addingTimeInterval(-2 * 3600),
                processType: "Kassenbeleg-V1",
                signatureValue: "MEQCIAjklK3194aX99eQ21nFw19w0zLaP==",
                qrCodeData: "V0;KL-CASH-01;2;2026-10-23T16:00:00Z;2026-10-23T16:00:04Z;2;MEQCIAjklK3194;TSE-KL-DEMO-001"
            )
        ]
    }

    public func loadCashbook() async throws -> [KitchenLinkCashbookEntry] {
        return entries.sorted { $0.entryNumber > $1.entryNumber }
    }

    public func recordExpense(
        amountCents: Int,
        taxRate: Decimal?,
        receiptNumber: String?,
        description: String
    ) async throws -> KitchenLinkCashbookEntry {
        let currentBalance = entries.last?.balanceAfterCents ?? 0
        let newBalance = currentBalance - amountCents
        let nextNumber = (entries.map(\.entryNumber).max() ?? 0) + 1

        var taxCents = 0
        if let rate = taxRate, rate > 0 {
            let rateD = (rate as NSDecimalNumber).doubleValue
            let net = Double(amountCents) / (1.0 + (rateD / 100.0))
            taxCents = Int(Double(amountCents) - net)
        }

        let newEntry = KitchenLinkCashbookEntry(
            entryNumber: nextNumber,
            bookingDate: Date(),
            entryType: .expense,
            amountCents: amountCents,
            isIncome: false,
            balanceAfterCents: newBalance,
            taxRatePercent: taxRate,
            taxCents: taxCents,
            receiptNumber: receiptNumber,
            description: description
        )
        entries.append(newEntry)
        return newEntry
    }

    public func recordDeposit(amountCents: Int, description: String) async throws -> KitchenLinkCashbookEntry {
        let currentBalance = entries.last?.balanceAfterCents ?? 0
        let newBalance = currentBalance + amountCents
        let nextNumber = (entries.map(\.entryNumber).max() ?? 0) + 1

        let newEntry = KitchenLinkCashbookEntry(
            entryNumber: nextNumber,
            bookingDate: Date(),
            entryType: .deposit,
            amountCents: amountCents,
            isIncome: true,
            balanceAfterCents: newBalance,
            description: description
        )
        entries.append(newEntry)
        return newEntry
    }

    public func loadTSETransactions() async throws -> [KitchenLinkTSETransaction] {
        return tseTransactions.sorted { $0.transactionNumber > $1.transactionNumber }
    }

    public func signTSETransaction(amountCents: Int, processType: String) async throws -> KitchenLinkTSETransaction {
        let nextTx = (tseTransactions.map(\.transactionNumber).max() ?? 0) + 1
        let nextSig = (tseTransactions.map(\.signatureCounter).max() ?? 0) + 1
        let now = Date()

        let sig = "SIG-TSE-DEMO-\(UUID().uuidString.prefix(16))=="
        let qr = "V0;KL-CASH-01;\(nextTx);\(now);\(now);\(nextSig);\(sig.prefix(12));TSE-KL-DEMO-001"

        let tx = KitchenLinkTSETransaction(
            transactionNumber: nextTx,
            signatureCounter: nextSig,
            startedAt: now.addingTimeInterval(-3),
            finishedAt: now,
            processType: processType,
            signatureValue: sig,
            qrCodeData: qr
        )
        tseTransactions.append(tx)
        return tx
    }
}
