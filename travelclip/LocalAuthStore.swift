//
//  LocalAuthStore.swift
//  travelclip
//

import Combine
import CryptoKit
import Foundation

struct AuthenticatedUser: Equatable {
    let id: UUID
    let displayName: String
    let email: String
}

@MainActor
final class LocalAuthStore: ObservableObject {
    @Published private(set) var currentUser: AuthenticatedUser?

    private let usersKey = "travelclip.localAuth.users"
    private let sessionKey = "travelclip.localAuth.sessionUserID"
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        restoreSession()
    }

    var isSignedIn: Bool {
        currentUser != nil
    }

    func signIn(email: String, password: String) -> Result<Void, LocalAuthError> {
        let normalizedEmail = normalize(email)
        guard !normalizedEmail.isEmpty, !password.isEmpty else {
            return .failure(.missingCredentials)
        }

        guard let user = storedUsers().first(where: { $0.email == normalizedEmail }) else {
            return .failure(.invalidCredentials)
        }

        guard user.passwordDigest == digest(password: password, salt: user.passwordSalt) else {
            return .failure(.invalidCredentials)
        }

        startSession(for: user)
        return .success(())
    }

    func register(displayName: String, email: String, password: String) -> Result<Void, LocalAuthError> {
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedEmail = normalize(email)
        let passwordIssue = validatePassword(password)

        guard !trimmedName.isEmpty, !normalizedEmail.isEmpty else {
            return .failure(.missingCredentials)
        }

        guard normalizedEmail.contains("@"), normalizedEmail.contains(".") else {
            return .failure(.invalidEmail)
        }

        if let passwordIssue {
            return .failure(passwordIssue)
        }

        var users = storedUsers()
        guard users.contains(where: { $0.email == normalizedEmail }) == false else {
            return .failure(.emailAlreadyRegistered)
        }

        let salt = UUID().uuidString
        let user = StoredAuthUser(
            id: UUID(),
            displayName: trimmedName,
            email: normalizedEmail,
            passwordSalt: salt,
            passwordDigest: digest(password: password, salt: salt),
            createdAt: Date()
        )
        users.append(user)
        save(users)
        startSession(for: user)
        return .success(())
    }

    func signOut() {
        userDefaults.removeObject(forKey: sessionKey)
        currentUser = nil
    }

    private func restoreSession() {
        guard
            let sessionIDString = userDefaults.string(forKey: sessionKey),
            let sessionID = UUID(uuidString: sessionIDString),
            let user = storedUsers().first(where: { $0.id == sessionID })
        else {
            currentUser = nil
            return
        }

        currentUser = user.authenticatedUser
    }

    private func startSession(for user: StoredAuthUser) {
        userDefaults.set(user.id.uuidString, forKey: sessionKey)
        currentUser = user.authenticatedUser
    }

    private func storedUsers() -> [StoredAuthUser] {
        guard let data = userDefaults.data(forKey: usersKey) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([StoredAuthUser].self, from: data)) ?? []
    }

    private func save(_ users: [StoredAuthUser]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(users) else { return }
        userDefaults.set(data, forKey: usersKey)
    }

    private func normalize(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func validatePassword(_ password: String) -> LocalAuthError? {
        guard password.count >= 8 else { return .weakPassword }
        guard password.rangeOfCharacter(from: .decimalDigits) != nil else { return .weakPassword }
        guard password.rangeOfCharacter(from: .letters) != nil else { return .weakPassword }
        return nil
    }

    private func digest(password: String, salt: String) -> String {
        let input = "\(salt):\(password)"
        let digest = SHA256.hash(data: Data(input.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

enum LocalAuthError: LocalizedError, Equatable {
    case missingCredentials
    case invalidEmail
    case weakPassword
    case emailAlreadyRegistered
    case invalidCredentials

    var errorDescription: String? {
        switch self {
        case .missingCredentials:
            return "请输入名称、邮箱和密码。"
        case .invalidEmail:
            return "请输入有效邮箱。"
        case .weakPassword:
            return "密码至少 8 位，并包含字母和数字。"
        case .emailAlreadyRegistered:
            return "这个邮箱已经注册过。"
        case .invalidCredentials:
            return "邮箱或密码不正确。"
        }
    }
}

private struct StoredAuthUser: Codable {
    var id: UUID
    var displayName: String
    var email: String
    var passwordSalt: String
    var passwordDigest: String
    var createdAt: Date

    var authenticatedUser: AuthenticatedUser {
        AuthenticatedUser(id: id, displayName: displayName, email: email)
    }
}
