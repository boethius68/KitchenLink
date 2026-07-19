import Foundation

public struct KitchenLinkVenueHubBonjourDescriptor: Equatable, Identifiable, Sendable {
    public let hubID: String
    public let name: String
    public let baseURL: URL

    public var id: String { hubID }

    public init(hubID: String, name: String, baseURL: URL) {
        self.hubID = hubID
        self.name = name
        self.baseURL = baseURL
    }
}

public enum KitchenLinkVenueHubBonjourContract {
    public static let serviceType = "_kitchenlink-hub._tcp"
    public static let schemaVersion = "1"

    private static let hubIDKey = "id"
    private static let versionKey = "v"
    private static let baseURLKey = "url"
    private static let displayNameKey = "name"

    public static func record(
        hubID: String,
        baseURL: URL?,
        displayName: String? = nil
    ) -> [String: String] {
        var record = [
            hubIDKey: hubID,
            versionKey: schemaVersion
        ]
        if let baseURL, isValidBaseURL(baseURL) {
            record[baseURLKey] = baseURL.absoluteString
        }
        if let displayName {
            let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedName.isEmpty {
                record[displayNameKey] = trimmedName
            }
        }
        return record
    }

    public static func descriptor(
        serviceName: String,
        record: [String: String]
    ) -> KitchenLinkVenueHubBonjourDescriptor? {
        guard record[versionKey] == schemaVersion,
              let rawHubID = record[hubIDKey],
              let rawBaseURL = record[baseURLKey],
              let baseURL = URL(string: rawBaseURL),
              isValidBaseURL(baseURL) else {
            return nil
        }

        let hubID = rawHubID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !hubID.isEmpty else { return nil }
        let advertisedName = record[displayNameKey] ?? serviceName
        let trimmedName = advertisedName.trimmingCharacters(in: .whitespacesAndNewlines)
        return KitchenLinkVenueHubBonjourDescriptor(
            hubID: hubID,
            name: trimmedName.isEmpty ? "KitchenLink Venue Hub" : trimmedName,
            baseURL: baseURL
        )
    }

    private static func isValidBaseURL(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "http",
              url.host != nil,
              url.port != nil,
              url.user == nil,
              url.password == nil,
              url.query == nil,
              url.fragment == nil else {
            return false
        }
        return url.path.isEmpty || url.path == "/"
    }
}
