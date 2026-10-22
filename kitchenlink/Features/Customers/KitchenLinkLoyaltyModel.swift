import Foundation

/// KL-LOYALTY-001: Kundenkonto, Loyalty, Gutscheine & Feedback (Blueprint §13 & Meilenstein 5).

public enum KitchenLinkCustomerTier: String, CaseIterable, Identifiable, Sendable {
    case bronze = "bronze"
    case silver = "silver"
    case gold = "gold"
    case vip = "vip"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .bronze: return "Bronze"
        case .silver: return "Silber"
        case .gold: return "Gold"
        case .vip: return "VIP Stammgast"
        }
    }

    public var badgeIcon: String {
        switch self {
        case .bronze: return "star"
        case .silver: return "star.leadinghalf.filled"
        case .gold: return "star.fill"
        case .vip: return "crown.fill"
        }
    }
}

public struct KitchenLinkCustomerProfile: Identifiable, Equatable, Sendable {
    public let id: String
    public var name: String
    public var email: String?
    public var phone: String?
    public var loyaltyPoints: Int
    public var tier: KitchenLinkCustomerTier
    public var totalOrdersCount: Int
    public var totalSpentCents: Int

    public init(
        id: String = UUID().uuidString,
        name: String,
        email: String? = nil,
        phone: String? = nil,
        loyaltyPoints: Int = 0,
        tier: KitchenLinkCustomerTier = .bronze,
        totalOrdersCount: Int = 0,
        totalSpentCents: Int = 0
    ) {
        self.id = id
        self.name = name
        self.email = email
        self.phone = phone
        self.loyaltyPoints = loyaltyPoints
        self.tier = tier
        self.totalOrdersCount = totalOrdersCount
        self.totalSpentCents = totalSpentCents
    }

    public var formattedSpent: String {
        let euros = Double(totalSpentCents) / 100.0
        return String(format: "%.2f €", locale: Locale(identifier: "de_DE"), euros)
    }
}

public struct KitchenLinkVoucher: Identifiable, Equatable, Sendable {
    public let id: String
    public var code: String
    public var discountType: String // "percentage" or "fixed_amount"
    public var discountValue: Int
    public var minOrderCents: Int
    public var maxUses: Int?
    public var timesUsed: Int
    public var validUntil: Date?
    public var isActive: Bool

    public init(
        id: String = UUID().uuidString,
        code: String,
        discountType: String = "percentage",
        discountValue: Int = 10,
        minOrderCents: Int = 0,
        maxUses: Int? = nil,
        timesUsed: Int = 0,
        validUntil: Date? = nil,
        isActive: Bool = true
    ) {
        self.id = id
        self.code = code
        self.discountType = discountType
        self.discountValue = discountValue
        self.minOrderCents = minOrderCents
        self.maxUses = maxUses
        self.timesUsed = timesUsed
        self.validUntil = validUntil
        self.isActive = isActive
    }

    public var discountDescription: String {
        if discountType == "percentage" {
            return "\(discountValue)% Rabatt"
        } else {
            let euros = Double(discountValue) / 100.0
            return String(format: "%.2f € Rabatt", locale: Locale(identifier: "de_DE"), euros)
        }
    }

    public var formattedMinOrder: String {
        if minOrderCents <= 0 { return "Kein Mindestbestellwert" }
        let euros = Double(minOrderCents) / 100.0
        return String(format: "ab %.2f €", locale: Locale(identifier: "de_DE"), euros)
    }
}

public struct KitchenLinkOrderFeedback: Identifiable, Equatable, Sendable {
    public let id: String
    public var orderID: String
    public var orderNumber: String
    public var rating: Int // 1 to 5
    public var comment: String?
    public var createdAt: Date

    public init(
        id: String = UUID().uuidString,
        orderID: String,
        orderNumber: String,
        rating: Int,
        comment: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.orderID = orderID
        self.orderNumber = orderNumber
        self.rating = rating
        self.comment = comment
        self.createdAt = createdAt
    }

    public var starsString: String {
        String(repeating: "★", count: rating) + String(repeating: "☆", count: max(0, 5 - rating))
    }
}

public protocol KitchenLinkLoyaltyProviding: Sendable {
    func loadCustomers() async throws -> [KitchenLinkCustomerProfile]
    func loadVouchers() async throws -> [KitchenLinkVoucher]
    func createVoucher(code: String, discountType: String, discountValue: Int, minOrderCents: Int) async throws -> KitchenLinkVoucher
    func loadFeedbacks() async throws -> [KitchenLinkOrderFeedback]
}

public actor KitchenLinkLoyaltyDemoProvider: KitchenLinkLoyaltyProviding {
    private var customers: [KitchenLinkCustomerProfile]
    private var vouchers: [KitchenLinkVoucher]
    private var feedbacks: [KitchenLinkOrderFeedback]

    public init() {
        let now = Date()
        self.customers = [
            KitchenLinkCustomerProfile(
                name: "Clara Schumann",
                email: "clara.schumann@beispiel.de",
                phone: "0170 1122334",
                loyaltyPoints: 420,
                tier: .gold,
                totalOrdersCount: 14,
                totalSpentCents: 41250
            ),
            KitchenLinkCustomerProfile(
                name: "Dr. Jan Weber",
                email: "jan.weber@praxis-berlin.de",
                phone: "0175 4433221",
                loyaltyPoints: 180,
                tier: .silver,
                totalOrdersCount: 6,
                totalSpentCents: 16500
            ),
            KitchenLinkCustomerProfile(
                name: "Elena Varga",
                email: "elena.varga@posteo.de",
                loyaltyPoints: 50,
                tier: .bronze,
                totalOrdersCount: 2,
                totalSpentCents: 5800
            )
        ]

        self.vouchers = [
            KitchenLinkVoucher(
                code: "WILLKOMMEN10",
                discountType: "percentage",
                discountValue: 10,
                minOrderCents: 1500,
                timesUsed: 42,
                isActive: true
            ),
            KitchenLinkVoucher(
                code: "STAMMGAST5",
                discountType: "fixed_amount",
                discountValue: 500,
                minOrderCents: 2500,
                timesUsed: 18,
                isActive: true
            )
        ]

        self.feedbacks = [
            KitchenLinkOrderFeedback(
                orderID: UUID().uuidString,
                orderNumber: "KL-A101",
                rating: 5,
                comment: "Das Rindergulasch war phänomenal zart. Schneller und freundlicher Service!",
                createdAt: now.addingTimeInterval(-2 * 3600)
            ),
            KitchenLinkOrderFeedback(
                orderID: UUID().uuidString,
                orderNumber: "KL-B204",
                rating: 4,
                comment: "Gute Pizza, gerne etwas mehr Basilikum beim nächsten Mal.",
                createdAt: now.addingTimeInterval(-5 * 3600)
            ),
            KitchenLinkOrderFeedback(
                orderID: UUID().uuidString,
                orderNumber: "KL-C309",
                rating: 5,
                comment: "Wunderbares Ambiente im Gastraum. Wir kommen gerne wieder.",
                createdAt: now.addingTimeInterval(-24 * 3600)
            )
        ]
    }

    public func loadCustomers() async throws -> [KitchenLinkCustomerProfile] {
        return customers
    }

    public func loadVouchers() async throws -> [KitchenLinkVoucher] {
        return vouchers
    }

    public func createVoucher(code: String, discountType: String, discountValue: Int, minOrderCents: Int) async throws -> KitchenLinkVoucher {
        let newVoucher = KitchenLinkVoucher(
            code: code.uppercased(),
            discountType: discountType,
            discountValue: discountValue,
            minOrderCents: minOrderCents
        )
        vouchers.insert(newVoucher, at: 0)
        return newVoucher
    }

    public func loadFeedbacks() async throws -> [KitchenLinkOrderFeedback] {
        return feedbacks
    }
}
