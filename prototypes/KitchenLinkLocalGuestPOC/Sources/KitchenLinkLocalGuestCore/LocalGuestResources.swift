import Foundation

public enum LocalGuestResources {
    public static func indexHTML() throws -> Data {
        guard let url = Bundle.module.url(forResource: "index", withExtension: "html") else {
            throw ResourceError.missingIndexHTML
        }
        return try Data(contentsOf: url)
    }

    public enum ResourceError: Error {
        case missingIndexHTML
    }
}
