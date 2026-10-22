import XCTest
@testable import kitchenlink

final class KitchenLinkLoyaltyTests: XCTestCase {

    func testLoadDemoLoyaltyData() async throws {
        let provider = KitchenLinkLoyaltyDemoProvider()
        let customers = try await provider.loadCustomers()
        let vouchers = try await provider.loadVouchers()
        let feedbacks = try await provider.loadFeedbacks()

        XCTAssertEqual(customers.count, 3)
        XCTAssertEqual(vouchers.count, 2)
        XCTAssertEqual(feedbacks.count, 3)

        let clara = try XCTUnwrap(customers.first { $0.name == "Clara Schumann" })
        XCTAssertEqual(clara.tier, .gold)
        XCTAssertEqual(clara.loyaltyPoints, 420)
        XCTAssertEqual(clara.formattedSpent, "412,50 €")

        let voucher = try XCTUnwrap(vouchers.first { $0.code == "WILLKOMMEN10" })
        XCTAssertEqual(voucher.discountDescription, "10% Rabatt")
        XCTAssertEqual(voucher.formattedMinOrder, "ab 15,00 €")
    }

    func testCreateVoucher() async throws {
        let provider = KitchenLinkLoyaltyDemoProvider()

        let created = try await provider.createVoucher(
            code: "herbst20",
            discountType: "percentage",
            discountValue: 20,
            minOrderCents: 2000
        )

        XCTAssertEqual(created.code, "HERBST20")
        XCTAssertEqual(created.discountDescription, "20% Rabatt")
        XCTAssertEqual(created.formattedMinOrder, "ab 20,00 €")

        let allVouchers = try await provider.loadVouchers()
        XCTAssertTrue(allVouchers.contains { $0.code == "HERBST20" })
    }

    func testCustomerTiers() {
        XCTAssertEqual(KitchenLinkCustomerTier.bronze.title, "Bronze")
        XCTAssertEqual(KitchenLinkCustomerTier.vip.title, "VIP Stammgast")
        XCTAssertEqual(KitchenLinkCustomerTier.gold.badgeIcon, "star.fill")
    }

    func testFeedbackStarsString() {
        let fiveStar = KitchenLinkOrderFeedback(
            orderID: "1",
            orderNumber: "KL-100",
            rating: 5
        )
        XCTAssertEqual(fiveStar.starsString, "★★★★★")

        let threeStar = KitchenLinkOrderFeedback(
            orderID: "2",
            orderNumber: "KL-200",
            rating: 3
        )
        XCTAssertEqual(threeStar.starsString, "★★★☆☆")
    }
}
