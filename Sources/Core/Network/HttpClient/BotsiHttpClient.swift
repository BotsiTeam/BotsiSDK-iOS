//
//  BotsiHttpClient.swift
//  Botsi
//
//  Created by Vladyslav on 21.02.2025.
//

import Foundation

// MARK: - Backend
public struct BotsiHttpClient: Sendable {
    
    let sdkApiKey: String
    private let session: URLSession

    struct URLConstants {
        /// Botsi V2 API. Paths are relative to it, e.g. `profiles`.
        static let backendHost: URL = URL(string: "https://api.botsi.com/v2/")!
    }
    
    init(with configuration: BotsiConfiguration) {
        self.sdkApiKey = configuration.sdkApiKey
        self.session = URLSession(configuration: .default)
    }

    /// Sends a request and returns the `data` of the `{ "ok": true, "data": … }` reply.
    func send<Response: Decodable>(
        _ method: BotsiHTTPMethod,
        _ path: String,
        body: (any Encodable)? = nil
    ) async throws -> Response {
        let data = try await perform(method, path, body: body)
        do {
            return try JSONDecoder().decode(BotsiOkResponse<Response>.self, from: data).data
        } catch {
            BotsiLog.error("\(method.rawValue) \(path): unexpected response. \(error.localizedDescription)")
            throw BotsiError.networkError("Unexpected response from \(path)")
        }
    }

    /// Sends a request whose reply is `{ "ok": true }`.
    func send(
        _ method: BotsiHTTPMethod,
        _ path: String,
        body: (any Encodable)? = nil
    ) async throws {
        _ = try await perform(method, path, body: body)
    }

    private func perform(
        _ method: BotsiHTTPMethod,
        _ path: String,
        body: (any Encodable)?
    ) async throws -> Data {
        guard let url = URL(string: path, relativeTo: URLConstants.backendHost) else {
            throw BotsiError.networkError("Unable to build url for \(path)")
        }
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue(sdkApiKey, forHTTPHeaderField: "Authorization")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(body)
        }

        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            let error = BotsiError.api(status: status, data: data)
            BotsiLog.error("\(method.rawValue) \(path) failed: \(error.localizedDescription)")
            if status == 401 {
                throw BotsiError.sdkActivationKeyNotValid
            }
            throw error
        }
        return data
    }
}

/// Every successful V2 reply wraps its payload as `{ "ok": true, "data": … }`.
private struct BotsiOkResponse<Payload: Decodable>: Decodable {
    let data: Payload
}

extension String {
    /// Escapes a value, such as a profile ID, for use as one segment of a request path.
    var pathSegment: String {
        addingPercentEncoding(withAllowedCharacters: .urlPathAllowed.subtracting(CharacterSet(charactersIn: "/"))) ?? self
    }
}
