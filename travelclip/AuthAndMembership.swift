import Combine
import Foundation
import Security
import SwiftUI

struct AuthenticatedUser: Equatable {
    let id: UUID
    let displayName: String
    let email: String
}

@MainActor
final class LocalAuthStore: ObservableObject {
    @Published private(set) var currentUser: AuthenticatedUser?
    @Published private(set) var entitlement: MembershipEntitlement = .free
    @Published private(set) var isLoadingSession = false
    @Published var errorMessage: String?

    private let sessionKeychainKey = "travelclip.auth.token"
    private let userDefaults = UserDefaults.standard
    private let apiClient: APIClient
    private let adRewardManager: RewardedAdManager

    init(apiBaseURL: URL? = nil, adRewardManager: RewardedAdManager? = nil) {
        self.apiClient = APIClient(baseURL: apiBaseURL ?? Self.defaultAPIBaseURL)
        self.adRewardManager = adRewardManager ?? RewardedAdManager()
        restoreSession()
    }

    var isSignedIn: Bool {
        currentUser != nil
    }

    func signIn(email: String, password: String) async -> Result<Void, LocalAuthError> {
        await authenticate(email: email, password: password, path: "/auth/login")
    }

    func register(displayName: String, email: String, password: String) async -> Result<Void, LocalAuthError> {
        let payload = AuthPayload(displayName: displayName, email: email, password: password)
        return await authenticate(payload: payload, path: "/auth/register")
    }

    func signOut() {
        currentUser = nil
        entitlement = .free
        errorMessage = nil
        KeychainStore.delete(service: sessionKeychainService, account: sessionKeychainAccount)
    }

    func refreshSession() async {
        guard let token = KeychainStore.read(service: sessionKeychainService, account: sessionKeychainAccount) else {
            currentUser = nil
            entitlement = .free
            return
        }

        isLoadingSession = true
        defer { isLoadingSession = false }

        do {
            let response: AuthSessionResponse = try await apiClient.get("/me", token: token)
            apply(session: response, token: token)
        } catch {
            currentUser = nil
            entitlement = .free
            KeychainStore.delete(service: sessionKeychainService, account: sessionKeychainAccount)
        }
    }

    func canUse(_ accessLevel: AccessLevel) -> Bool {
        accessLevel == .free || entitlement.isPremium
    }

    func requestAdReward() async -> Bool {
        await adRewardManager.presentRewardedAd()
    }

    func claimAdUnlock(for assetID: String) async -> Bool {
        guard await requestAdReward() else { return false }
        // The first version only unlocks the current action locally.
        userDefaults.set(assetID, forKey: "travelclip.ad.lastUnlockedAssetID")
        return true
    }

    private func restoreSession() {
        Task { await refreshSession() }
    }

    private func authenticate(email: String, password: String, path: String) async -> Result<Void, LocalAuthError> {
        let payload = AuthPayload(displayName: nil, email: email, password: password)
        return await authenticate(payload: payload, path: path)
    }

    private func authenticate(payload: AuthPayload, path: String) async -> Result<Void, LocalAuthError> {
        guard !payload.email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !payload.password.isEmpty else {
            errorMessage = LocalAuthError.missingCredentials.errorDescription
            return .failure(.missingCredentials)
        }
        isLoadingSession = true
        errorMessage = nil
        defer { isLoadingSession = false }

        do {
            let response: AuthSessionResponse = try await apiClient.post(path, body: payload)
            apply(session: response, token: response.accessToken)
            return .success(())
        } catch let error as APIClientError {
            let mapped = error.mappedAuthError ?? .invalidCredentials
            errorMessage = mapped.errorDescription
            return .failure(mapped)
        } catch {
            errorMessage = LocalAuthError.invalidCredentials.errorDescription
            return .failure(.invalidCredentials)
        }
    }

    private func apply(session: AuthSessionResponse, token: String) {
        currentUser = session.user.authenticatedUser
        entitlement = session.entitlement ?? .free
        KeychainStore.save(token, service: sessionKeychainService, account: sessionKeychainAccount)
    }

    private var sessionKeychainService: String { "travelclip.auth.session" }
    private var sessionKeychainAccount: String { "default" }

    private static var defaultAPIBaseURL: URL {
        if let urlString = Bundle.main.object(forInfoDictionaryKey: "TRAVELCLIP_API_BASE_URL") as? String,
           let url = URL(string: urlString) {
            return url
        }
        return URL(string: "https://api.travelclip.app")!
    }
}

struct AuthPayload: Encodable {
    let displayName: String?
    let email: String
    let password: String
}

struct AuthSessionResponse: Decodable {
    let accessToken: String
    let user: RemoteUser
    let entitlement: MembershipEntitlement?
}

struct RemoteUser: Decodable {
    let id: UUID
    let displayName: String
    let email: String

    var authenticatedUser: AuthenticatedUser {
        AuthenticatedUser(id: id, displayName: displayName, email: email)
    }
}

enum LocalAuthError: LocalizedError, Equatable {
    case missingCredentials
    case invalidEmail
    case weakPassword
    case emailAlreadyRegistered
    case invalidCredentials
    case networkUnavailable

    var errorDescription: String? {
        switch self {
        case .missingCredentials: return "请输入名称、邮箱和密码。"
        case .invalidEmail: return "请输入有效邮箱。"
        case .weakPassword: return "密码至少 8 位，并包含字母和数字。"
        case .emailAlreadyRegistered: return "这个邮箱已经注册过。"
        case .invalidCredentials: return "邮箱或密码不正确。"
        case .networkUnavailable: return "网络不可用，请稍后再试。"
        }
    }
}

struct APIClient {
    let baseURL: URL

    func get<T: Decodable>(_ path: String, token: String) async throws -> T {
        let request = try request(path: path, method: "GET", token: token)
        return try await execute(request)
    }

    func post<T: Decodable>(_ path: String, body: some Encodable) async throws -> T {
        let request = try request(path: path, method: "POST", body: body)
        return try await execute(request)
    }

    private func request(path: String, method: String, token: String? = nil, body: (any Encodable)? = nil) throws -> URLRequest {
        guard let url = URL(string: path, relativeTo: baseURL) else { throw APIClientError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            request.httpBody = try JSONEncoder.travelclip.encode(AnyEncodable(body))
        }
        return request
    }

    private func execute<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIClientError.unexpectedResponse }
        guard 200..<300 ~= http.statusCode else {
            throw APIClientError.httpStatus(http.statusCode, data: data)
        }
        return try JSONDecoder.travelclip.decode(T.self, from: data)
    }
}

enum APIClientError: Error {
    case invalidURL
    case unexpectedResponse
    case httpStatus(Int, data: Data)
}

extension APIClientError {
    var mappedAuthError: LocalAuthError? {
        switch self {
        case .httpStatus(401, _): return .invalidCredentials
        case .httpStatus(409, _): return .emailAlreadyRegistered
        case .httpStatus(let status, _) where status >= 500: return .networkUnavailable
        default: return nil
        }
    }
}

private struct AnyEncodable: Encodable {
    private let encodeImpl: (Encoder) throws -> Void

    init<T: Encodable>(_ value: T) {
        self.encodeImpl = value.encode
    }

    func encode(to encoder: Encoder) throws {
        try encodeImpl(encoder)
    }
}

enum KeychainStore {
    static func save(_ value: String, service: String, account: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]
        SecItemAdd(addQuery as CFDictionary, nil)
    }

    static func read(service: String, account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(decoding: data, as: UTF8.self)
    }

    static func delete(service: String, account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}

extension JSONDecoder {
    static var travelclip: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

extension JSONEncoder {
    static var travelclip: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

@MainActor
final class RewardedAdManager: NSObject, ObservableObject {
    func presentRewardedAd() async -> Bool {
        false
    }
}
