//
//  AuthManager.swift
//  Hermes
//
//  Handles Supabase email OTP sign-in and profile synchronization.
//

import Foundation
import Supabase
import Auth
import AuthenticationServices
import AppKit

@MainActor
final class AuthManager: ObservableObject {
    static let shared = AuthManager()

    @Published private(set) var isSendingCode: Bool = false
    @Published private(set) var isVerifyingCode: Bool = false
    @Published private(set) var lastErrorMessage: String?
    @Published private(set) var isAuthenticated: Bool = false

    private init() {}

    // MARK: - Public API

    func sendEmailOTP(to email: String) async -> Bool {
        lastErrorMessage = nil
        isSendingCode = true
        defer { isSendingCode = false }
        do {
            // Send OTP to email (passwordless sign-in)
            try await supabase.auth.signInWithOTP(email: email)
            return true
        } catch {
            lastErrorMessage = "Failed to send code: \(error.localizedDescription)"
            return false
        }
    }

    func verifyEmailOTP(email: String, token: String) async -> Bool {
        lastErrorMessage = nil
        isVerifyingCode = true
        defer { isVerifyingCode = false }
        do {
            // Verify OTP and establish session
            try await supabase.auth.verifyOTP(email: email, token: token, type: .email)

            // Fetch user and profile
            try await applyCurrentUserAndProfile()
            return true
        } catch {
            lastErrorMessage = "Verification failed: \(error.localizedDescription)"
            return false
        }
    }

    // MARK: - Profile Sync

    func applyCurrentUserAndProfile() async throws {
        // Current authenticated user
        let user = try await supabase.auth.user()

        // Update last sign-in timestamp in profile
        let nowIso = ISO8601DateFormatter().string(from: Date())

        // Attempt to update/insert basic profile fields
        let basicProfile = Profile(
            id: user.id,
            email: user.email,
            display_name: Self.metadataString(user.userMetadata, key: "full_name"),
            avatar_url: Self.metadataString(user.userMetadata, key: "avatar_url"),
            last_sign_in_at: nowIso
        )

        // Upsert profile basic details
        _ = try? await supabase
            .database
            .from("profiles")
            .upsert(basicProfile)
            .execute()

        // Fetch full profile row
        let profile: Profile = try await supabase
            .database
            .from("profiles")
            .select()
            .eq("id", value: user.id)
            .single()
            .execute()
            .value

        // Apply to UserSettings
        let settings = UserSettings.shared
        settings.userEmail = profile.email ?? user.email
        settings.userDisplayName = profile.display_name ?? (profile.email?.split(separator: "@").first.map(String.init))
        settings.avatarURL = profile.avatar_url
        settings.subscriptionPlan = profile.subscription_plan ?? .free
        settings.isOnboardingCompleted = profile.is_onboarding_completed ?? settings.isOnboardingCompleted
        settings.privacySettings.isPrivacyModeEnabled = profile.is_privacy_mode_enabled ?? settings.privacySettings.isPrivacyModeEnabled
        settings.privacySettings.allowCloudSync = profile.allow_cloud_sync ?? settings.privacySettings.allowCloudSync
        settings.lastSyncDate = Date()
        settings.saveToLocalStorage()
        isAuthenticated = true
    }

    // MARK: - OAuth (Google)

    func signInWithGoogle() async -> Bool {
        lastErrorMessage = nil
        do {
            let redirect = URL(string: "hermes://auth-callback")!
            let url = try await supabase.auth.getOAuthSignInURL(
                provider: .google,
                redirectTo: redirect
            )
            let callbackURL = try await authenticate(using: url, callbackScheme: redirect.scheme!)
            try await supabase.auth.session(from: callbackURL)
            try await applyCurrentUserAndProfile()
            return true
        } catch {
            lastErrorMessage = "Google sign-in failed: \(error.localizedDescription)"
            return false
        }
    }

    func handleOAuthRedirect(_ url: URL) async {
        do {
            try await supabase.auth.session(from: url)
            try await applyCurrentUserAndProfile()
            // Persist settings to Supabase profiles as part of callback
            let settings = UserSettings.shared
            if settings.privacySettings.allowCloudSync {
                let payload = ProfileUpdatePayload(
                    id: try await supabase.auth.user().id,
                    is_onboarding_completed: settings.isOnboardingCompleted,
                    is_privacy_mode_enabled: settings.privacySettings.isPrivacyModeEnabled,
                    allow_cloud_sync: settings.privacySettings.allowCloudSync,
                    onboarding_settings: settings.onboardingSettings,
                    keyboard_shortcuts: settings.keyboardShortcuts,
                    privacy_settings: settings.privacySettings,
                    dictation_settings: settings.dictationSettings,
                    interface_settings: settings.interfaceSettings,
                    team_settings: settings.teamSettings
                )
                _ = try? await supabase.database
                    .from("profiles")
                    .upsert(payload)
                    .execute()
            }
        } catch {
            lastErrorMessage = "OAuth completion failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - Helpers

private extension AuthManager {
    static func metadataString(_ metadata: [String: AnyJSON], key: String) -> String? {
        if let any = metadata[key], case let .string(value) = any {
            return value
        }
        return nil
    }

    func authenticate(using url: URL, callbackScheme: String) async throws -> URL {
        return try await withCheckedThrowingContinuation { continuation in
            let provider = WebAuthPresentationProvider()
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: callbackScheme
            ) { callbackURL, error in
                if let callbackURL = callbackURL {
                    continuation.resume(returning: callbackURL)
                } else {
                    continuation.resume(throwing: error ?? NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Authentication cancelled"]))
                }
            }
            session.presentationContextProvider = provider
            session.prefersEphemeralWebBrowserSession = true
            if !session.start() {
                continuation.resume(throwing: NSError(domain: "Auth", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to start authentication session"]))
            }
        }
    }
}

private final class WebAuthPresentationProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return NSApplication.shared.windows.first ?? NSWindow()
    }
}

// MARK: - Supabase Profile Model

struct Profile: Codable {
    let id: UUID
    let email: String?
    let display_name: String?
    let avatar_url: String?
    let last_sign_in_at: String?

    // Optional settings mirrored from DB (if present)
    let subscription_plan: SubscriptionPlan?
    let is_onboarding_completed: Bool?
    let is_privacy_mode_enabled: Bool?
    let allow_cloud_sync: Bool?

    init(
        id: UUID,
        email: String? = nil,
        display_name: String? = nil,
        avatar_url: String? = nil,
        last_sign_in_at: String? = nil,
        subscription_plan: SubscriptionPlan? = nil,
        is_onboarding_completed: Bool? = nil,
        is_privacy_mode_enabled: Bool? = nil,
        allow_cloud_sync: Bool? = nil
    ) {
        self.id = id
        self.email = email
        self.display_name = display_name
        self.avatar_url = avatar_url
        self.last_sign_in_at = last_sign_in_at
        self.subscription_plan = subscription_plan
        self.is_onboarding_completed = is_onboarding_completed
        self.is_privacy_mode_enabled = is_privacy_mode_enabled
        self.allow_cloud_sync = allow_cloud_sync
    }
}

// Payload for updating settings JSON in profiles
struct ProfileUpdatePayload: Codable {
    let id: UUID
    let is_onboarding_completed: Bool
    let is_privacy_mode_enabled: Bool
    let allow_cloud_sync: Bool
    let onboarding_settings: OnboardingSettings
    let keyboard_shortcuts: KeyboardShortcuts
    let privacy_settings: PrivacySettings
    let dictation_settings: DictationSettings
    let interface_settings: InterfaceSettings
    let team_settings: TeamSettings?
}


