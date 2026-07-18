import Foundation

public struct HTTPRequest: Equatable, Sendable {
    public let method: String
    public let path: String
    public let headers: [String: String]
    public let body: Data

    public init(method: String, path: String, headers: [String: String] = [:], body: Data = Data()) {
        self.method = method
        self.path = path
        self.headers = headers
        self.body = body
    }
}

public struct HTTPResponse: Equatable, Sendable {
    public let status: Int
    public let reason: String
    public let contentType: String
    public let body: Data

    public init(status: Int, reason: String, contentType: String, body: Data) {
        self.status = status
        self.reason = reason
        self.contentType = contentType
        self.body = body
    }

    public func encoded() -> Data {
        var head = "HTTP/1.1 \(status) \(reason)\r\n"
        head += "Content-Type: \(contentType)\r\n"
        head += "Content-Length: \(body.count)\r\n"
        head += "Cache-Control: no-store\r\n"
        head += "X-Content-Type-Options: nosniff\r\n"
        head += "Referrer-Policy: no-referrer\r\n"
        head += "Connection: close\r\n\r\n"
        var data = Data(head.utf8)
        data.append(body)
        return data
    }
}

public final class HTTPRouter: @unchecked Sendable {
    private let service: LocalGuestOrderService
    private let indexHTML: Data
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(service: LocalGuestOrderService, indexHTML: Data) {
        self.service = service
        self.indexHTML = indexHTML
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        self.decoder = JSONDecoder()
    }

    public func route(_ request: HTTPRequest) -> HTTPResponse {
        let path = request.path.split(separator: "?", maxSplits: 1).first.map(String.init) ?? request.path
        switch (request.method.uppercased(), path) {
        case ("GET", "/"), ("GET", "/menu"):
            return HTTPResponse(status: 200, reason: "OK", contentType: "text/html; charset=utf-8", body: indexHTML)
        case ("GET", "/health"):
            return json(status: 200, reason: "OK", value: ["status": "ok", "mode": "sandbox-local"])
        case ("GET", "/bootstrap"):
            return json(status: 200, reason: "OK", value: service.bootstrap())
        case ("POST", "/orders"):
            return placeOrder(request)
        default:
            return error(status: 404, reason: "Not Found", code: "not_found", message: "Route nicht gefunden.")
        }
    }

    private func placeOrder(_ request: HTTPRequest) -> HTTPResponse {
        guard request.body.count <= 64 * 1024 else {
            return error(status: 413, reason: "Payload Too Large", code: "payload_too_large", message: "Bestellung ist zu groß.")
        }
        let contentType = request.headers.first { key, _ in
            key.lowercased() == "content-type"
        }?.value.split(separator: ";", maxSplits: 1).first?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard contentType == "application/json" else {
            return error(
                status: 415,
                reason: "Unsupported Media Type",
                code: "unsupported_media_type",
                message: "Bestellungen müssen als application/json gesendet werden."
            )
        }
        do {
            let order = try decoder.decode(LocalOrderRequest.self, from: request.body)
            let receipt = try service.placeOrder(order)
            return json(status: receipt.replayed ? 200 : 201, reason: receipt.replayed ? "OK" : "Created", value: receipt)
        } catch let serviceError as LocalGuestOrderService.ServiceError {
            switch serviceError {
            case .invalidRequest(let message):
                return error(status: 422, reason: "Unprocessable Content", code: "invalid_order", message: message)
            case .idempotencyConflict:
                return error(status: 409, reason: "Conflict", code: "idempotency_conflict", message: "Dieser Wiederholungsschlüssel gehört zu einer anderen Bestellung.")
            case .persistence:
                return error(status: 503, reason: "Service Unavailable", code: "not_persisted", message: "Die Bestellung wurde nicht bestätigt. Bitte erneut versuchen.")
            }
        } catch {
            return self.error(status: 400, reason: "Bad Request", code: "invalid_json", message: "Ungültige Bestelldaten.")
        }
    }

    private func json<T: Encodable>(status: Int, reason: String, value: T) -> HTTPResponse {
        do {
            return HTTPResponse(status: status, reason: reason, contentType: "application/json; charset=utf-8", body: try encoder.encode(value))
        } catch {
            return self.error(status: 500, reason: "Internal Server Error", code: "encoding_failed", message: "Antwort konnte nicht erzeugt werden.")
        }
    }

    private func error(status: Int, reason: String, code: String, message: String) -> HTTPResponse {
        let document = APIErrorDocument(error: code, message: message)
        let body = (try? encoder.encode(document)) ?? Data("{\"error\":\"unknown\"}".utf8)
        return HTTPResponse(status: status, reason: reason, contentType: "application/json; charset=utf-8", body: body)
    }
}
