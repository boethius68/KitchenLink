import Foundation

// MARK: - Sandbox week fixture

/// Deterministische Fixture für einen typischen Restaurantbetrieb mit Service,
/// Küche und Bar. Alle Zeiten sind in Europe/Berlin angegeben. Die Fixture
/// ist rein domänenseitig und enthält keine UI oder Persistenz.
struct WorkforceSandboxWeekFixture: Sendable {

    let timeZone: TimeZone
    let calendar: Calendar
    let mondayStart: Date

    // Venues
    let venueID: WorkforceID = "venue-lichterfelde"

    // Stations
    let serviceStation: WorkforceStation
    let kitchenStation: WorkforceStation
    let barStation: WorkforceStation
    var stations: [WorkforceID: WorkforceStation] { [serviceStation.id: serviceStation, kitchenStation.id: kitchenStation, barStation.id: barStation] }

    // Employees
    let anna: WorkforceEmployee
    let ben: WorkforceEmployee
    let clara: WorkforceEmployee
    let david: WorkforceEmployee
    let elena: WorkforceEmployee
    var employees: [WorkforceEmployee]

    // Assignments
    var assignments: [WorkforceVenueAssignment]

    // Templates
    let serviceLunchTemplate: WorkforceShiftTemplate
    let serviceDinnerTemplate: WorkforceShiftTemplate
    let kitchenLunchTemplate: WorkforceShiftTemplate
    let barEveningTemplate: WorkforceShiftTemplate

    var templates: [WorkforceShiftTemplate] {
        [serviceLunchTemplate, serviceDinnerTemplate, kitchenLunchTemplate, barEveningTemplate]
    }

    // Planned shifts
    var plannedShifts: [WorkforcePlannedShift]

    // Venue shift
    var venueShift: WorkforceVenueShift

    init(referenceDate: Date = Date(timeIntervalSince1970: 1_756_000_000)) throws {
        guard let tz = TimeZone(identifier: "Europe/Berlin") else {
            throw FixtureError.missingTimeZone
        }
        self.timeZone = tz
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        self.calendar = cal

        // Align to the Monday of the reference week.
        var components = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: referenceDate)
        components.weekday = 2 // Monday
        guard let monday = cal.date(from: components) else {
            throw FixtureError.dateAlignmentFailed
        }
        self.mondayStart = monday

        // Stations
        self.serviceStation = WorkforceStation(
            id: "station-service",
            name: "Service",
            colorHex: "6B4EFF",
            requiredQualifications: []
        )
        self.kitchenStation = WorkforceStation(
            id: "station-kitchen",
            name: "Küche",
            colorHex: "FF6B4E",
            requiredQualifications: [.foodSafety]
        )
        self.barStation = WorkforceStation(
            id: "station-bar",
            name: "Bar",
            colorHex: "4E9BFF",
            requiredQualifications: [.barLicense]
        )

        // Employees
        self.anna = WorkforceEmployee(
            id: "emp-anna",
            givenName: "Anna",
            familyName: "Schmidt",
            email: "anna@example.kitchen",
            joinedAt: monday.addingTimeInterval(-365 * 24 * 3600),
            roles: [.manager, .shiftLead, .service],
            qualifications: [.foodSafety, .cashRegister, .shiftLead],
            isActive: true
        )
        self.ben = WorkforceEmployee(
            id: "emp-ben",
            givenName: "Ben",
            familyName: "Müller",
            joinedAt: monday.addingTimeInterval(-180 * 24 * 3600),
            roles: [.service],
            qualifications: [.cashRegister],
            isActive: true
        )
        self.clara = WorkforceEmployee(
            id: "emp-clara",
            givenName: "Clara",
            familyName: "Weber",
            joinedAt: monday.addingTimeInterval(-90 * 24 * 3600),
            roles: [.kitchen],
            qualifications: [.foodSafety],
            isActive: true
        )
        self.david = WorkforceEmployee(
            id: "emp-david",
            givenName: "David",
            familyName: "Klein",
            joinedAt: monday.addingTimeInterval(-60 * 24 * 3600),
            roles: [.bar],
            qualifications: [.barLicense, .barista],
            isActive: true
        )
        self.elena = WorkforceEmployee(
            id: "emp-elena",
            givenName: "Elena",
            familyName: "Groß",
            joinedAt: monday.addingTimeInterval(-30 * 24 * 3600),
            roles: [.service, .bar],
            qualifications: [.barLicense, .cashRegister],
            isActive: true
        )

        self.employees = [anna, ben, clara, david, elena]

        // Assignments
        self.assignments = [
            WorkforceVenueAssignment(
                id: "assignment-anna",
                employeeID: anna.id,
                venueID: venueID,
                defaultHourlyRateCents: 1600,
                startedAt: anna.joinedAt,
                roles: [.manager, .shiftLead, .service],
                homeStations: [serviceStation.id]
            ),
            WorkforceVenueAssignment(
                id: "assignment-ben",
                employeeID: ben.id,
                venueID: venueID,
                defaultHourlyRateCents: 1300,
                startedAt: ben.joinedAt,
                roles: [.service],
                homeStations: [serviceStation.id]
            ),
            WorkforceVenueAssignment(
                id: "assignment-clara",
                employeeID: clara.id,
                venueID: venueID,
                defaultHourlyRateCents: 1400,
                startedAt: clara.joinedAt,
                roles: [.kitchen],
                homeStations: [kitchenStation.id]
            ),
            WorkforceVenueAssignment(
                id: "assignment-david",
                employeeID: david.id,
                venueID: venueID,
                defaultHourlyRateCents: 1450,
                startedAt: david.joinedAt,
                roles: [.bar],
                homeStations: [barStation.id]
            ),
            WorkforceVenueAssignment(
                id: "assignment-elena",
                employeeID: elena.id,
                venueID: venueID,
                defaultHourlyRateCents: 1350,
                startedAt: elena.joinedAt,
                roles: [.service, .bar],
                homeStations: [serviceStation.id, barStation.id]
            )
        ]

        // Templates
        self.serviceLunchTemplate = WorkforceShiftTemplate(
            id: "template-service-lunch",
            name: "Service Mittag",
            weekday: 2, // Monday
            startTime: WorkforceLocalTime(hour: 11, minute: 30),
            endTime: WorkforceLocalTime(hour: 15, minute: 0),
            timeZoneIdentifier: "Europe/Berlin",
            stationIDs: [serviceStation.id],
            requiredRoles: [.service],
            requiredQualifications: [],
            targetHeadcount: 2
        )
        self.serviceDinnerTemplate = WorkforceShiftTemplate(
            id: "template-service-dinner",
            name: "Service Abend",
            weekday: 2,
            startTime: WorkforceLocalTime(hour: 17, minute: 30),
            endTime: WorkforceLocalTime(hour: 23, minute: 0),
            timeZoneIdentifier: "Europe/Berlin",
            stationIDs: [serviceStation.id],
            requiredRoles: [.service],
            requiredQualifications: [],
            targetHeadcount: 2
        )
        self.kitchenLunchTemplate = WorkforceShiftTemplate(
            id: "template-kitchen-lunch",
            name: "Küche Mittag",
            weekday: 2,
            startTime: WorkforceLocalTime(hour: 11, minute: 0),
            endTime: WorkforceLocalTime(hour: 15, minute: 30),
            timeZoneIdentifier: "Europe/Berlin",
            stationIDs: [kitchenStation.id],
            requiredRoles: [.kitchen],
            requiredQualifications: [.foodSafety],
            targetHeadcount: 1
        )
        self.barEveningTemplate = WorkforceShiftTemplate(
            id: "template-bar-evening",
            name: "Bar Abend",
            weekday: 2,
            startTime: WorkforceLocalTime(hour: 18, minute: 0),
            endTime: WorkforceLocalTime(hour: 23, minute: 30),
            timeZoneIdentifier: "Europe/Berlin",
            stationIDs: [barStation.id],
            requiredRoles: [.bar],
            requiredQualifications: [.barLicense],
            targetHeadcount: 1
        )

        // Planned shifts for Monday
        let mondayLunch = try Self.resolveTemplate(serviceLunchTemplate, on: monday, calendar: cal, venueID: venueID, employeeID: anna.id, templateID: serviceLunchTemplate.id)
        let mondayDinner = try Self.resolveTemplate(serviceDinnerTemplate, on: monday, calendar: cal, venueID: venueID, employeeID: ben.id, templateID: serviceDinnerTemplate.id)
        let mondayKitchen = try Self.resolveTemplate(kitchenLunchTemplate, on: monday, calendar: cal, venueID: venueID, employeeID: clara.id, templateID: kitchenLunchTemplate.id)
        let mondayBar = try Self.resolveTemplate(barEveningTemplate, on: monday, calendar: cal, venueID: venueID, employeeID: david.id, templateID: barEveningTemplate.id)

        var publishedShifts = [mondayLunch, mondayDinner, mondayKitchen, mondayBar]
        for index in publishedShifts.indices {
            _ = publishedShifts[index].publish(at: monday)
        }
        self.plannedShifts = publishedShifts

        // Venue operating shift
        let venueStart = monday.addingTimeInterval(10 * 3600 + 30 * 60)
        let venueEnd = monday.addingTimeInterval(25 * 3600) // Overnight
        self.venueShift = WorkforceVenueShift(
            id: "venue-shift-monday",
            venueID: venueID,
            range: WorkforceTimeRange(startsAt: venueStart, endsAt: venueEnd),
            timeZoneIdentifier: "Europe/Berlin",
            openedBy: anna.id,
            closedBy: nil,
            closedAt: nil,
            startingCashCents: 20000
        )
    }

    private static func resolveTemplate(
        _ template: WorkforceShiftTemplate,
        on date: Date,
        calendar: Calendar,
        venueID: WorkforceID,
        employeeID: WorkforceID,
        templateID: WorkforceID
    ) throws -> WorkforcePlannedShift {
        let range = try template.resolvedRange(on: date, calendar: calendar).get()
        return WorkforcePlannedShift(
            id: WorkforceID(rawValue: "shift-\(template.id.rawValue)-\(employeeID.rawValue)"),
            venueID: venueID,
            employeeID: employeeID,
            templateID: templateID,
            range: range,
            timeZoneIdentifier: template.timeZoneIdentifier,
            status: .draft,
            stationIDs: template.stationIDs,
            targetHeadcount: template.targetHeadcount,
            requiredQualifications: template.requiredQualifications,
            publishedAt: nil,
            acceptedAt: nil,
            declinedAt: nil,
            declineReason: nil,
            swapRequestID: nil,
            note: nil
        )
    }

    func dateTime(dayOffset: Int, hour: Int, minute: Int) -> Date {
        var components = calendar.dateComponents([.year, .month, .day], from: mondayStart)
        components.day = (components.day ?? 0) + dayOffset
        components.hour = hour
        components.minute = minute
        components.second = 0
        return calendar.date(from: components) ?? mondayStart
    }

    /// Erzeugt einen Validierungskontext für diese Fixture.
    func validationContext(availabilities: [WorkforceAvailability] = [], leaves: [WorkforceLeave] = []) -> WorkforceValidationContext {
        WorkforceValidationContext(
            employees: Dictionary(uniqueKeysWithValues: employees.map { ($0.id, $0) }),
            assignments: Dictionary(uniqueKeysWithValues: assignments.map { ($0.id, $0) }),
            stations: stations,
            plannedShifts: plannedShifts,
            availabilities: availabilities,
            leaves: leaves,
            timeEntries: [],
            breakEntries: [],
            venueShifts: [venueShift]
        )
    }

    enum FixtureError: Error, Equatable {
        case missingTimeZone
        case dateAlignmentFailed
    }
}

