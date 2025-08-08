//
//  SignInStepView.swift
//  Hermes
//
//  Created by Claude Code on 7/23/25.
//

import SwiftUI
import AppKit

/// SIGN IN step - contains authentication, free trial, data privacy, and welcome survey sub-flows
struct SignInStepView: View {
    @State private var currentSubStep: SignInSubStep = .authentication
    @EnvironmentObject private var coordinator: OnboardingCoordinator
    
    var body: some View {
        OnboardingStepContainer(
            showBackButton: canGoBack,
            useScrollView: true,
            verticalAlignment: .balanced
        ) {
            Group {
                switch currentSubStep {
                case .authentication:
                    AuthenticationView(onContinue: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentSubStep = .freeTrial
                        }
                    })
                case .freeTrial:
                    FreeTrialView(onContinue: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentSubStep = .dataPrivacy
                        }
                    })
                case .dataPrivacy:
                    DataPrivacyView(onContinue: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentSubStep = .welcomeSurvey
                        }
                    })
                case .welcomeSurvey:
                    WelcomeSurveyView(onContinue: {
                        coordinator.nextStep()
                    })
                }
            }
        }
        .onAppear {
            // Set up sub-step back navigation handler
            coordinator.subStepBackHandler = handleSubStepBack
        }
        .onDisappear {
            // Clean up handler when leaving this step
            coordinator.subStepBackHandler = nil
        }
    }
    
    private var canGoBack: Bool {
        currentSubStep != .authentication
    }
    
    private func handleSubStepBack() -> Bool {
        switch currentSubStep {
        case .authentication:
            return false // Can't go back from first sub-step
        case .freeTrial:
            withAnimation(.easeInOut(duration: 0.3)) {
                currentSubStep = .authentication
            }
            return true
        case .dataPrivacy:
            withAnimation(.easeInOut(duration: 0.3)) {
                currentSubStep = .freeTrial
            }
            return true
        case .welcomeSurvey:
            withAnimation(.easeInOut(duration: 0.3)) {
                currentSubStep = .dataPrivacy
            }
            return true
        }
    }
}

enum SignInSubStep {
    case authentication
    case freeTrial
    case dataPrivacy
    case welcomeSurvey
}

// MARK: - Sub-step Views

private struct AuthenticationView: View {
    let onContinue: () -> Void
    @State private var showEmailSection = false
    @State private var email: String = ""
    
    var body: some View {
        VStack(spacing: 24) {
            // App icon (uses asset if available for better light/dark rendering)
            OnboardingLogoView()
                .frame(width: 96, height: 96)
            
            VStack(spacing: 12) {
                Text("Get started with Hermes")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("Dictate 3x faster. Everywhere you type.")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
            }
            
                VStack(spacing: 24) {
                // OAuth buttons - 4 options in 2x2 grid with proper spacing
                VStack(spacing: 16) {
                    HStack(spacing: 16) {
                            Button("Sign in with Google") {
                            onContinue()
                        }
                            .googleButtonStyle()
                        
                        Button("Sign in with Apple") {
                            onContinue()
                        }
                        .appleButtonStyle()
                    }
                    
                    HStack(spacing: 16) {
                        Button("Sign in with Microsoft") {
                            onContinue()
                        }
                        .microsoftButtonStyle()
                        
                            Button("Single sign-on (SSO)") {
                            onContinue()
                        }
                        .ssoButtonStyle()
                    }
                }

                // Divider with OR (persistent between OAuth and email)
                HStack {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(height: 1)
                    Text("OR")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 16)
                    Rectangle()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(height: 1)
                }
                .padding(.vertical, 4)

                // Email toggle button
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        showEmailSection.toggle()
                    }
                }) {
                    Text(showEmailSection ? "Hide email sign in" : "Continue with Email")
                }
                .secondaryNeutralButtonStyle()

                // Email input section - expands/collapses below the toggle
                if showEmailSection {
                    VStack(spacing: 16) {
                        HermesTextField(
                            text: $email,
                            placeholder: "Enter your work or school email"
                        )
                        .frame(width: 400)

                        Text("Use your work or school email to enjoy the upcoming team and collaboration features.")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(width: 400)

                        Button("Continue with Email") {
                            onContinue()
                        }
                        .primaryButtonStyle()
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
                
                Text("By signing up, you agree to our Terms of Service and Privacy Policy. Your name and email will be used to personalize your Hermes experience.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(width: 380)
                    .padding(.top, 6)
            }
        }
    }
    
}

// Prefer asset "OnboardingLogo" (PNG/PDF) if available; fall back to system glyph
private struct OnboardingLogoView: View {
    var body: some View {
        if NSImage(named: "OnboardingLogo") != nil {
            Image("OnboardingLogo")
                .resizable()
                .renderingMode(.original)
                .scaledToFit()
                .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 3)
        } else {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(Color(hex: HermesConstants.primaryAccentColor))
        }
    }
}

private struct FreeTrialView: View {
    struct TrialConfig {
        let userFirstName: String
        let trialDays: Int
        let productName: String
        let endDateText: String
        let pricePerMonthText: String
        let features: [String]
        let requiresCreditCard: Bool

        static let `default` = TrialConfig(
            userFirstName: "isabel",
            trialDays: 14,
            productName: "Hermes Pro",
            endDateText: "August 6",
            pricePerMonthText: "$12/month",
            features: [
                "Unlimited words per week",
                "Access to command mode"
            ],
            requiresCreditCard: false
        )
    }

    let onContinue: () -> Void
    let config: TrialConfig

    init(onContinue: @escaping () -> Void, config: TrialConfig = .default) {
        self.onContinue = onContinue
        self.config = config
    }

    private var trialDurationText: String {
        if config.trialDays % 7 == 0 {
            "\(config.trialDays / 7) weeks"
        } else {
            "\(config.trialDays) days"
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            // Title
            Text("Congratulations \(config.userFirstName.capitalized)!")
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)

            // Centered card container
            VStack(spacing: 16) {
                // Headline
                VStack(spacing: 6) {
                    Text("Enjoy \(trialDurationText) of")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                    Text(config.productName)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.primary)
                }

                // Badges row
                HStack(spacing: 8) {
                    Text("Free")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color(hex: HermesConstants.primaryAccentColor)))
                    Text("No credit card required")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }

                Divider().opacity(0.5)

                // Features
                VStack(alignment: .center, spacing: 8) {
                    Text("Everything in Basic, plus:")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    VStack(spacing: 6) {
                        ForEach(config.features, id: \.self) { item in
                            featureItem(item)
                        }
                    }
                }
                .frame(maxWidth: .infinity)

                // Details
                VStack(spacing: 6) {
                    Text("Unlimited access until \(config.endDateText).")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                    Text("Upgrade any time for \(config.pricePerMonthText).")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Text("If you don’t upgrade by \(config.endDateText), you’ll return to Hermes Basic.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(24)
            .frame(maxWidth: 520)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 4)

            Button("Continue") {
                onContinue()
            }
            .primaryButtonStyle()
        }
    }
    
    private func featureItem(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16))
                .foregroundColor(Color(hex: HermesConstants.primaryAccentColor))
            
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

private struct DataPrivacyView: View {
    let onContinue: () -> Void
    @State private var selectedMode: PrivacyMode = .helpImprove
    
    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 12) {
                Text("You control your data")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.primary)
            }
            
            VStack(spacing: 16) {
                // Help improve option
                privacyOption(
                    mode: .helpImprove,
                    title: "Help improve Hermes",
                    description: "To make Hermes better, this option lets us collect your audio, transcript, and edits to evaluate, train and improve Hermes's features and AI models",
                    isSelected: selectedMode == .helpImprove
                ) {
                    selectedMode = .helpImprove
                }
                
                // Privacy mode option
                privacyOption(
                    mode: .privacyMode,
                    title: "Privacy Mode",
                    description: "If you enable Privacy Mode, none of your dictation data will be stored or used for model training by us or any third party.",
                    isSelected: selectedMode == .privacyMode,
                    hasLockIcon: true
                ) {
                    selectedMode = .privacyMode
                }
                
                Text("You can always change this later in settings.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("Read more here.")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
            
            Button("Continue") {
                onContinue()
            }
            .primaryButtonStyle()
        }
    }
    
    private func privacyOption(
        mode: PrivacyMode,
        title: String,
        description: String,
        isSelected: Bool,
        hasLockIcon: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 12) {
                HStack {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                    Spacer()
                    if hasLockIcon {
                        Image(systemName: "lock.fill")
                            .foregroundColor(Color(hex: HermesConstants.primaryAccentColor))
                    }
                }
                
                Text(description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
            }
            .padding()
            .frame(width: 400)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color(hex: HermesConstants.primaryAccentColor).opacity(0.1) : Color(NSColor.controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color(hex: HermesConstants.primaryAccentColor) : Color.clear, lineWidth: 2)
                    )
            )
        }
        .plainHoverButtonStyle()
    }
    
    enum PrivacyMode {
        case helpImprove
        case privacyMode
    }
}

private struct WelcomeSurveyView: View {
    let onContinue: () -> Void
    @State private var selectedSource = "Reddit"
    
    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 12) {
                Text("Welcome, isabel!")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("Where did you hear about us?")
                    .font(.body)
                    .foregroundColor(.secondary)
                
                Text("(Optional)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
            }
            
            VStack(spacing: 20) {
                HermesDropdown(
                    selection: $selectedSource,
                    options: ["Reddit", "Twitter", "LinkedIn", "Friend referral", "Other"],
                    placeholder: "Where did you hear about us?"
                )
                .frame(width: 250)
                
                VStack(spacing: 12) {
                    Button("Continue") {
                        onContinue()
                    }
                    .primaryButtonStyle()
                    
                    Button("Skip") {
                        onContinue()
                    }
                    .secondaryButtonStyle()
                }
            }
        }
    }
}

#Preview {
    SignInStepView()
        .environmentObject(OnboardingCoordinator(
            currentStep: .constant(.signIn),
            showingOnboarding: .constant(true)
        ))
        .frame(width: 1000, height: 700)
}