import Darwin
import Foundation
import KitchenLinkLocalGuestCore

struct Configuration {
    let port: UInt16
    let publicHost: String
    let databasePath: String

    static func parse(_ arguments: [String]) throws -> Configuration {
        var port: UInt16 = 8080
        var publicHost = "127.0.0.1"
        var databasePath = FileManager.default.currentDirectoryPath + "/kitchenlink-local-orders.sqlite"
        var index = 1
        while index < arguments.count {
            let flag = arguments[index]
            guard index + 1 < arguments.count else {
                throw CLIError.invalid("Wert für \(flag) fehlt.")
            }
            let value = arguments[index + 1]
            switch flag {
            case "--port":
                guard let parsed = UInt16(value), parsed > 0 else { throw CLIError.invalid("Ungültiger Port.") }
                port = parsed
            case "--public-host":
                publicHost = value
            case "--database":
                databasePath = value
            default:
                throw CLIError.invalid("Unbekannte Option: \(flag)")
            }
            index += 2
        }
        return Configuration(port: port, publicHost: publicHost, databasePath: databasePath)
    }
}

enum CLIError: Error, CustomStringConvertible {
    case invalid(String)
    var description: String {
        switch self { case .invalid(let message): return message }
    }
}

final class LocalHTTPServer {
    private let router: HTTPRouter
    private let port: UInt16

    init(router: HTTPRouter, port: UInt16) {
        self.router = router
        self.port = port
    }

    func run() throws -> Never {
        signal(SIGPIPE, SIG_IGN)
        let serverFD = socket(AF_INET, SOCK_STREAM, 0)
        guard serverFD >= 0 else { throw POSIXError(.ENOTSOCK) }
        var reuse: Int32 = 1
        guard setsockopt(serverFD, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout.size(ofValue: reuse))) == 0 else {
            Darwin.close(serverFD)
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EINVAL)
        }

        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = port.bigEndian
        address.sin_addr = in_addr(s_addr: INADDR_ANY)
        let bindResult = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(serverFD, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bindResult == 0, listen(serverFD, 16) == 0 else {
            let code = POSIXErrorCode(rawValue: errno) ?? .EINVAL
            Darwin.close(serverFD)
            throw POSIXError(code)
        }

        while true {
            let clientFD = accept(serverFD, nil, nil)
            if clientFD < 0 {
                if errno == EINTR { continue }
                throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EINVAL)
            }
            handle(clientFD)
            Darwin.close(clientFD)
        }
    }

    private func handle(_ fd: Int32) {
        let response: HTTPResponse
        do {
            let request = try readRequest(fd)
            response = router.route(request)
        } catch {
            response = HTTPResponse(
                status: 400,
                reason: "Bad Request",
                contentType: "application/json; charset=utf-8",
                body: Data("{\"error\":\"bad_request\",\"message\":\"Ungültige HTTP-Anfrage.\"}".utf8)
            )
        }
        writeAll(response.encoded(), to: fd)
    }

    private func readRequest(_ fd: Int32) throws -> HTTPRequest {
        var data = Data()
        var expectedLength: Int?
        let headerDelimiter = Data("\r\n\r\n".utf8)

        while data.count <= 128 * 1024 {
            var buffer = [UInt8](repeating: 0, count: 4096)
            let count = Darwin.read(fd, &buffer, buffer.count)
            guard count > 0 else { throw CLIError.invalid("Verbindung beendet.") }
            data.append(contentsOf: buffer.prefix(count))

            if let headerRange = data.range(of: headerDelimiter) {
                if expectedLength == nil {
                    let headerData = data[..<headerRange.lowerBound]
                    guard let headerText = String(data: headerData, encoding: .utf8) else { throw CLIError.invalid("Header ist nicht UTF-8.") }
                    expectedLength = contentLength(in: headerText)
                }
                let bodyStart = headerRange.upperBound
                if data.count - bodyStart >= (expectedLength ?? 0) { break }
            }
        }

        guard let headerRange = data.range(of: headerDelimiter), data.count <= 128 * 1024 else {
            throw CLIError.invalid("HTTP-Anfrage ist zu groß oder unvollständig.")
        }
        guard let headerText = String(data: data[..<headerRange.lowerBound], encoding: .utf8) else {
            throw CLIError.invalid("Header ist nicht UTF-8.")
        }
        let lines = headerText.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else { throw CLIError.invalid("Request-Line fehlt.") }
        let parts = requestLine.split(separator: " ")
        guard parts.count == 3 else { throw CLIError.invalid("Request-Line ist ungültig.") }
        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            guard let colon = line.firstIndex(of: ":") else { continue }
            headers[String(line[..<colon]).lowercased()] = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
        }
        let length = Int(headers["content-length"] ?? "0") ?? 0
        let bodyStart = headerRange.upperBound
        guard length <= 64 * 1024, data.count >= bodyStart + length else { throw CLIError.invalid("Body ist ungültig.") }
        return HTTPRequest(
            method: String(parts[0]),
            path: String(parts[1]),
            headers: headers,
            body: data.subdata(in: bodyStart..<(bodyStart + length))
        )
    }

    private func contentLength(in headers: String) -> Int {
        for line in headers.components(separatedBy: "\r\n") {
            let parts = line.split(separator: ":", maxSplits: 1)
            if parts.count == 2, parts[0].lowercased() == "content-length" {
                return Int(parts[1].trimmingCharacters(in: .whitespaces)) ?? 0
            }
        }
        return 0
    }

    private func writeAll(_ data: Data, to fd: Int32) {
        data.withUnsafeBytes { rawBuffer in
            guard var base = rawBuffer.baseAddress else { return }
            var remaining = rawBuffer.count
            while remaining > 0 {
                let sent = Darwin.write(fd, base, remaining)
                guard sent > 0 else { return }
                remaining -= sent
                base = base.advanced(by: sent)
            }
        }
    }
}

do {
    let configuration = try Configuration.parse(CommandLine.arguments)
    guard let htmlURL = Bundle.module.url(forResource: "index", withExtension: "html") else {
        throw CLIError.invalid("Gastseite fehlt im Bundle.")
    }
    let html = try Data(contentsOf: htmlURL)
    let service = try LocalGuestOrderService(databasePath: configuration.databasePath)
    let router = HTTPRouter(service: service, indexHTML: html)
    let url = "http://\(configuration.publicHost):\(configuration.port)/"
    print("KitchenLink Local Guest Ordering PoC (SANDBOX)")
    print("Gast-URL: \(url)")
    print("Bootstrap: \(url)bootstrap")
    print("Datenbank: \(configuration.databasePath)")
    print("Hinweis: --public-host muss für echte Geräte die LAN-IPv4-Adresse enthalten.")
    try LocalHTTPServer(router: router, port: configuration.port).run()
} catch {
    FileHandle.standardError.write(Data("Start fehlgeschlagen: \(error)\n".utf8))
    exit(1)
}
