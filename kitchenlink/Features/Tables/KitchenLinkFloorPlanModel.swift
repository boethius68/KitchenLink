import Foundation
import SwiftUI

/// KL-TABLE-003: Grafischer Tischplan, Raumstatus & Tisch-Transfer (Blueprint §10).
///
/// Ermöglicht dem Servicepersonal die Raumübersicht mit Live-Belegungsstatus,
/// Erfassung von Umsetzungen (Tisch-Transfer) und Tisch-Zusammenlegungen.

public enum KitchenLinkTableShape: String, CaseIterable, Identifiable, Sendable {
    case round = "round"
    case square = "square"
    case rectangle = "rectangle"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .round: return "Rund"
        case .square: return "Quadratisch"
        case .rectangle: return "Rechteckig"
        }
    }
}

public enum KitchenLinkFloorPlanOccupancy: Equatable, Sendable {
    case free
    case occupied(sessionID: String, startedAt: Date, orderCount: Int, totalCents: Int)
    case reserved(time: String, guestName: String, partySize: Int)
    case inactive

    public var title: String {
        switch self {
        case .free: return "Frei"
        case .occupied: return "Belegt"
        case .reserved: return "Reserviert"
        case .inactive: return "Stillgelegt"
        }
    }

    public var isOccupied: Bool {
        if case .occupied = self { return true }
        return false
    }

    public var isFree: Bool {
        self == .free
    }

    public var isReserved: Bool {
        if case .reserved = self { return true }
        return false
    }
}

public struct KitchenLinkFloorPlanTable: Identifiable, Equatable, Sendable {
    public let id: String
    public var label: String
    public var area: String
    public var sortOrder: Int
    public var active: Bool
    public var seats: Int
    public var shape: KitchenLinkTableShape
    public var posX: Int
    public var posY: Int
    public var token: String?
    public var occupancy: KitchenLinkFloorPlanOccupancy

    public init(
        id: String,
        label: String,
        area: String = "Gastraum",
        sortOrder: Int = 10,
        active: Bool = true,
        seats: Int = 4,
        shape: KitchenLinkTableShape = .square,
        posX: Int = 0,
        posY: Int = 0,
        token: String? = nil,
        occupancy: KitchenLinkFloorPlanOccupancy = .free
    ) {
        self.id = id
        self.label = label
        self.area = area
        self.sortOrder = sortOrder
        self.active = active
        self.seats = seats
        self.shape = shape
        self.posX = posX
        self.posY = posY
        self.token = token
        self.occupancy = occupancy
    }

    public var headline: String {
        KitchenLinkTableLabel.headline(label)
    }

    public var areaOrDefault: String {
        let trimmed = area.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? "Gastraum" : trimmed
    }
}

public protocol KitchenLinkFloorPlanProviding: Sendable {
    func loadFloorPlan() async throws -> [KitchenLinkFloorPlanTable]
    func transferSession(fromTableID: String, toTableID: String) async throws
    func mergeTables(sourceTableID: String, targetTableID: String) async throws
}

/// Actor-basierter Demo-Provider für Sandbox- und Testumgebungen.
public actor KitchenLinkFloorPlanDemoProvider: KitchenLinkFloorPlanProviding {
    private var tables: [KitchenLinkFloorPlanTable]

    public init(initialTables: [KitchenLinkFloorPlanTable]? = nil) {
        if let initial = initialTables {
            self.tables = initial
        } else {
            let now = Date()
            self.tables = [
                KitchenLinkFloorPlanTable(
                    id: "table-1",
                    label: "1",
                    area: "Gastraum",
                    sortOrder: 10,
                    active: true,
                    seats: 4,
                    shape: .square,
                    posX: 0,
                    posY: 0,
                    token: "tok-1",
                    occupancy: .occupied(
                        sessionID: "sess-1",
                        startedAt: now.addingTimeInterval(-2100), // 35 Min. her
                        orderCount: 3,
                        totalCents: 4250
                    )
                ),
                KitchenLinkFloorPlanTable(
                    id: "table-2",
                    label: "2",
                    area: "Gastraum",
                    sortOrder: 20,
                    active: true,
                    seats: 2,
                    shape: .round,
                    posX: 1,
                    posY: 0,
                    token: "tok-2",
                    occupancy: .occupied(
                        sessionID: "sess-2",
                        startedAt: now.addingTimeInterval(-720), // 12 Min. her
                        orderCount: 2,
                        totalCents: 1800
                    )
                ),
                KitchenLinkFloorPlanTable(
                    id: "table-3",
                    label: "3",
                    area: "Gastraum",
                    sortOrder: 30,
                    active: true,
                    seats: 4,
                    shape: .square,
                    posX: 0,
                    posY: 1,
                    token: "tok-3",
                    occupancy: .reserved(
                        time: "19:00",
                        guestName: "Familie Sommer",
                        partySize: 4
                    )
                ),
                KitchenLinkFloorPlanTable(
                    id: "table-4",
                    label: "4",
                    area: "Gastraum",
                    sortOrder: 40,
                    active: true,
                    seats: 4,
                    shape: .square,
                    posX: 1,
                    posY: 1,
                    token: "tok-4",
                    occupancy: .free
                ),
                KitchenLinkFloorPlanTable(
                    id: "table-5",
                    label: "5",
                    area: "Gastraum",
                    sortOrder: 50,
                    active: true,
                    seats: 6,
                    shape: .rectangle,
                    posX: 2,
                    posY: 1,
                    token: "tok-5",
                    occupancy: .free
                ),
                KitchenLinkFloorPlanTable(
                    id: "table-t1",
                    label: "T1",
                    area: "Terrasse",
                    sortOrder: 60,
                    active: true,
                    seats: 4,
                    shape: .round,
                    posX: 0,
                    posY: 0,
                    token: "tok-t1",
                    occupancy: .occupied(
                        sessionID: "sess-3",
                        startedAt: now.addingTimeInterval(-3000), // 50 Min. her
                        orderCount: 4,
                        totalCents: 6400
                    )
                ),
                KitchenLinkFloorPlanTable(
                    id: "table-t2",
                    label: "T2",
                    area: "Terrasse",
                    sortOrder: 70,
                    active: true,
                    seats: 2,
                    shape: .round,
                    posX: 1,
                    posY: 0,
                    token: "tok-t2",
                    occupancy: .free
                ),
                KitchenLinkFloorPlanTable(
                    id: "table-t3",
                    label: "T3",
                    area: "Terrasse",
                    sortOrder: 80,
                    active: true,
                    seats: 4,
                    shape: .square,
                    posX: 2,
                    posY: 0,
                    token: "tok-t3",
                    occupancy: .free
                )
            ]
        }
    }

    public func loadFloorPlan() async throws -> [KitchenLinkFloorPlanTable] {
        tables
    }

    public func transferSession(fromTableID: String, toTableID: String) async throws {
        guard let sourceIdx = tables.firstIndex(where: { $0.id == fromTableID }) else {
            throw KitchenLinkFloorPlanError.notFound("Quelltisch nicht gefunden")
        }
        guard let targetIdx = tables.firstIndex(where: { $0.id == toTableID }) else {
            throw KitchenLinkFloorPlanError.notFound("Zieltisch nicht gefunden")
        }

        guard case .occupied = tables[sourceIdx].occupancy else {
            throw KitchenLinkFloorPlanError.invalidOperation("Quelltisch ist nicht belegt")
        }

        guard tables[targetIdx].occupancy.isFree else {
            throw KitchenLinkFloorPlanError.invalidOperation("Zieltisch ist nicht frei")
        }

        let sessionOccupancy = tables[sourceIdx].occupancy
        tables[sourceIdx].occupancy = .free
        tables[targetIdx].occupancy = sessionOccupancy
    }

    public func mergeTables(sourceTableID: String, targetTableID: String) async throws {
        guard let sourceIdx = tables.firstIndex(where: { $0.id == sourceTableID }) else {
            throw KitchenLinkFloorPlanError.notFound("Quelltisch nicht gefunden")
        }
        guard let targetIdx = tables.firstIndex(where: { $0.id == targetTableID }) else {
            throw KitchenLinkFloorPlanError.notFound("Zieltisch nicht gefunden")
        }

        guard case .occupied(let sID, let sStarted, let sCount, let sCents) = tables[sourceIdx].occupancy,
              case .occupied(_, let tStarted, let tCount, let tCents) = tables[targetIdx].occupancy else {
            throw KitchenLinkFloorPlanError.invalidOperation("Beide Tische müssen belegt sein")
        }

        _ = sID
        let earliestStart = min(sStarted, tStarted)
        tables[targetIdx].occupancy = .occupied(
            sessionID: "merged-\(UUID().uuidString.prefix(6))",
            startedAt: earliestStart,
            orderCount: sCount + tCount,
            totalCents: sCents + tCents
        )
        tables[sourceIdx].occupancy = .free
    }
}

public enum KitchenLinkFloorPlanError: LocalizedError {
    case notFound(String)
    case invalidOperation(String)
    case serverError(String)

    public var errorDescription: String? {
        switch self {
        case .notFound(let msg): return msg
        case .invalidOperation(let msg): return msg
        case .serverError(let msg): return msg
        }
    }
}
